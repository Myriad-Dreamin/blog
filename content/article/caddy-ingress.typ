#import "/typ/templates/blog.typ": *
#show: main-en.with(
  title: "Hosting Multiple Websites using Caddy",
  desc: [To host multiple websites on a single server, I tried nginx, caddy, and traefik, and finally use caddy.],
  date: "2025-06-02T10:50:39+08:00",
  tags: (
    blog-tags.dev-ops,
    blog-tags.network,
    blog-tags.golang,
  ),
)

#set raw(
  syntaxes: (
    "/assets/dir-tree.sublime-syntax",
    "/assets/Caddyfile.sublime-syntax",
  ),
)

I bought a VPS to host my websites, a home page (i.myriad-dreamin.com) and a mirror site of my blog (cn.myriad-dreamin.com). Since Cloudflare is not available in my country, I'd better host them on my own server instead of proxying them through Cloudflare.

= Directory Structure

The directory structure of the websites is as follows:

```dir-tree
deployment
├── docker-compose.yml
├── caddy
│   ├── config
│   │   └── Caddyfile
│   ├── log
│   └── data
├── nginx
│   ├── conf
│   │   └── nginx.conf
│   └── log
├── dist
│   ├── i.myriad-dreamin.com
│   │   └── index.html
│   └── cn.myriad-dreamin.com
│       └── index.html
└── certbot
    ├── ssl
    └── www
```

The `docker-compose.yml` file contains all containers running for the websites The `dist` directory contains the static files for each website. The `caddy` or `nginx` have their owned directory to store the configuration files and logs. A `certbot` directory contains the SSL certificates and the webroot for certbot.

= Serving `dist` through HTTP File Server

I don't want to use integrated file servers from `caddy` or `nginx`. I would like have some fine-grained control over the files. For example, I would like to cache fonts permanently. So I seek a simple HTTP file server implementation. As usual, I first tried to find one written in Rust, but failed.

I have to admit that Rust is not a good (or simple) choice to build web services. There are some heavy engine, but I don't want to use them. If I turn my eyes to lightweight ones, I find they are not well maintained or not feature complete. My last try was #link("https://github.com/tiny-http/tiny-http")[tiny-http], which deserves a look. It is almost great, but I'm still not satisfied with it.

If I'm going to build some network things, why not use Go? I had good memory of writing network tools and services in Go. It is an indisputable good start. I start it with less than 10 lines of code, and it works well:

```go
package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: file-server <port> (:80)")
	}
	var port = os.Args[1]

	http.Handle("/", http.FileServer(http.Dir(".")))

	log.Println("Server listening on", port)
	log.Fatal(http.ListenAndServe(port, nil))
}
```

I also made some other improvments, like `gzip` compression:

```go
// https://gist.github.com/bryfry/09a650eb8aac0fb76c24
import (
	"compress/gzip"
	"io"
	"strings"
)

type GzipResponseWriter struct {
	io.Writer
	http.ResponseWriter
}

func (w GzipResponseWriter) Write(b []byte) (int, error) {
	return w.Writer.Write(b)
}

func Gzip(handler http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
			handler.ServeHTTP(w, r)
			return
		}
		w.Header().Set("Content-Encoding", "gzip")
		gz := gzip.NewWriter(w)
		defer gz.Close()
		gzw := GzipResponseWriter{Writer: gz, ResponseWriter: w}
		handler.ServeHTTP(gzw, r)
	})
}
```

And change the main function to use the `Gzip` middleware:

```diff
 func main() {
   ...
-  http.Handle("/", http.FileServer(http.Dir(".")))
+  fs := http.FileServer(http.Dir("."))
+  http.Handle("/", Gzip(fs))
   ...
 }
```

Again, I only used standard libraries to build my custom tools. `gopls`, as one of my favorite language server, completed all of the package imports automatically.

= HTTPS File Server?

About 4 years ago, I had experience to build a HTTPS file server using Go, but this is not a best practice in my view. Considering that I have to make an ingress controller, the SSL/TLS could be handled in middle. This mitigates both the complexity and attack surface of http services.

= Building the HTTP File Server Container

It is not needed to build a custom image for the file server, if you use the following command to build the Go program:

```bash
CGO_ENABLED=0 go build -tags netgo -o target/file-server ./cmd/file-server
```

Simply start a `alpine` container with the file server binary mounted as a volume, and it will work well. The `docker-compose.yml` file is as follows:

```yml
services:
    homepage:
        container_name: homepage
        image: alpine:latest
        restart: unless-stopped
        environment:
            TZ : 'Asia/Shanghai'
        working_dir: /app
        volumes:
            - /usr/local/bin/file-server:/usr/local/bin/file-server:ro
            - ./dist/homepage/:/app/
        command: 'file-server :80'
```

= Building Ingress using Nginx

I used both Caddy and Nginx. Both of them are good in my mind. Since it is not so disturbing to try both of them, I first tried Nginx, whose docker image is maintained by docker officially：

First, add a container for Nginx in `docker-compose.yml`:

```yml
services:
  nginx:
      container_name: nginx
      image: nginx
      restart: unless-stopped
      ports:
          - "80:80"
          - "443:443"
      environment:
          TZ : 'Asia/Shanghai'
      volumes:
          - ./nginx/conf:/etc/nginx
          - ./nginx/web:/usr/share/nginx
          - ./nginx/log:/var/log/nginx
          - ./certbot/www:/usr/share/certbot/www:ro
          - ./certbot/ssl:/usr/share/certbot/ssl:ro
      command:  nginx -g 'daemon off;'
```

And add a configuration file `nginx.conf` in `nginx/conf` directory:

```conf
events {
    worker_connections  4096;
}
http {
    server {
        listen 80;
        listen [::]:80;

        server_name  orange.myriad-dreamin.com;
        server_tokens off;

        location /.well-known/acme-challenge/ {
            root /usr/share/certbot/www;
        }
        location / {
            return 301 https://orange.myriad-dreamin.com$request_uri;
        }
    }
}
```

Note that `location /.well-known/acme-challenge/` is intercepted for HTTP challenge from certbot, which is used to obtain SSL certificates. The `location /` block redirects all HTTP traffic to HTTPS.

Then, running `docker compose up -d nginx` to start the Nginx container. The Nginx will listen on port 80 and 443.

= Making SSL Certificates using Certbot

Add a `certbot` container in `docker-compose.yml`:

```yml
services:
    certbot:
      container_name: certbot
      image: certbot/certbot
      volumes:
          - ./certbot/www:/usr/share/certbot/www:rw
          - ./certbot/ssl:/etc/letsencrypt:rw
```

Dry running the certbot to check if everything is fine:
```bash
docker compose run --rm  certbot certonly --webroot --webroot-path /usr/share/certbot/www/ --dry-run -d orange.myriad-dreamin.com
```

And then remove the `--dry-run` flag to obtain the real certificates.

If everything is fine, the certificates will be stored in `certbot/ssl` directory.

= Serving HTTPS using Nginx

The SSL certificates should be accessible in `/usr/share/certbot/ssl/live/orange.myriad-dreamin.com`. Let's add a server block in `nginx.conf` to serve the HTTPS traffic:


```conf
http {
    log_format main  '$remote_addr - $remote_user [$time_local] "$request" '
                  'status=$status body_bytes_sent=$body_bytes_sent http_referer="$http_referer" '
                  'http_user_agent="$http_user_agent" http_x_forwarded_for="$http_x_forwarded_for"';

    server {
        listen       443 ssl;
        listen [::]:443  ssl;
        server_name  orange.myriad-dreamin.com;

        access_log  /var/log/nginx/orange.myriad-dreamin.com.access.log  main;
        error_log  /var/log/nginx/orange.myriad-dreamin.com.error.log;

        ssl_certificate /usr/share/certbot/ssl/live/orange.myriad-dreamin.com/fullchain.pem;
        ssl_certificate_key /usr/share/certbot/ssl/live/orange.myriad-dreamin.com/privkey.pem;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;

        location / {
            proxy_pass http://homepage;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header REMOTE-HOST $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
```

Since we use `docker compose`, The `http://homepage` is resolved by the Docker's internal DNS to the `homepage` container, which is running the HTTP file server we started earlier.

To support a new site, just copy the two server blocks (another one is in the previous section) about `orange.myriad-dreamin.com` and change the `server_name` to the new site name. I thing this is simple enough.

= The Bad Guys are Accessing My Sites

From the logs, I found that there are some bad guys trying to access my site. They are trying to access many common paths, like `/admin`, `/login`, `/wp-login.php`, etc. That's interesting. Luckily, I only have read-only static files, and both Nginx and Golang HTTP file server are robust enough. But even if Nginx has been used for 20 years, we can usually see CVEs about it. Caddy does has slightly poorer performance, but my personal websites doesn't need to handle high traffic yet. `traefik` is another choice, but it is too complex and I might not use it for my personal websites. I think we can try Caddy next.

= Serving HTTP using Caddy

First add a `caddy` container in `docker-compose.yml`:

```yml
services:
    caddy:
        container_name: caddy
        image: caddy:latest
        restart: unless-stopped
        environment:
            TZ : 'Asia/Shanghai'
        ports:
        - "80:80"
        - "443:443"
        - "443:443/udp"
        volumes:
        - ./caddy/config:/etc/caddy
        - ./caddy/data:/data
        - ./caddy/log:/var/log/caddy
```

Then create a `Caddyfile` in `caddy/config` directory:

```caddy
:80 {
	respond "Hello World!"
}
```

We should be able to get a response containing ```typc "Hello World!"``` from the Caddy server by running `docker compose up -d caddy` and visiting `http://localhost:80`.

= Serving HTTPS using Caddy

Caddy can maintain the SSL certificates automatically, so we don't need to use `certbot` anymore. It will be pretty easy to set up a HTTPS server using Caddy. Just change the `Caddyfile` to:

```caddy
orange.myriad-dreamin.com {
	tls x@email.com
	reverse_proxy homepage
}
```

Once again, `homepage` is the name of the HTTP file server container, which is resolved by Docker's internal DNS.

Execute the following command to ensure the configuration is hot reloaded:

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Looks even much simpler than Nginx, right? Besides, Caddy is written in Go, so no memory bug will be introduced.

= Recording Access Logs

Caddy supports both Plaintext and JSON format for access logs. To enable access logs in Caddy, we can add the following snippet to the `Caddyfile`:

```
(subdomain-log) {
	log {
		hostnames {args[0]}
		format json
		output file /var/log/caddy/{args[0]}.jsonl {
			roll_size 100MiB
			roll_keep 3
			roll_keep_for 720h
		}
	}
}
```

And then include this snippet in each site block:
```diff
 orange.myriad-dreamin.com {
+  import subdomain-log orange.myriad-dreamin.com
	 tls x@email.com
	 reverse_proxy homepage
 }
```

I prefer JSON format, which is more structured and easier to parse. Among them, #link("https://github.com/pamburus/hl")[hl] is a good tool to parse JSON logs.

```bash
$ hl caddy/log/orange.myriad-dreamin.com.jsonl
Jun 01 01:02:03.456 [INF] http.log.access.log0: handled request request.remote-ip=a.b.c.d request.remote-port="xyz" request.client-ip=a.b.c.d ...
```

In fact, copilot helped me aggregate and display the access logs in a more readable way.

= List of Code

`docker-compose.yml`:

```yml
services:
    caddy:
        container_name: caddy
        image: caddy:latest
        restart: unless-stopped
        environment:
            TZ : 'Asia/Shanghai'
        ports:
        - "80:80"
        - "443:443"
        - "443:443/udp"
        volumes:
        - ./caddy/config:/etc/caddy
        - ./caddy/data:/data
        - ./caddy/log:/var/log/caddy
    homepage:
        container_name: homepage
        image: alpine:latest
        restart: unless-stopped
        environment:
            TZ : 'Asia/Shanghai'
        working_dir: /app
        volumes:
            - /usr/local/bin/file-server:/usr/local/bin/file-server:ro
            - ./dist/homepage/:/app/
        command: 'file-server :80'
```

`caddy/config/Caddyfile`:

```caddy
(subdomain-log) {
	log {
		hostnames {args[0]}
		format json
		output file /var/log/caddy/{args[0]}.jsonl {
			roll_size 100MiB
			roll_keep 3
			roll_keep_for 720h
		}
	}
}

orange.myriad-dreamin.com {
	import subdomain-log orange.myriad-dreamin.com
	tls x@email.com
	reverse_proxy homepage
}
```
