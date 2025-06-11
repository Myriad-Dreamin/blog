#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "使用Caddy托管多个网站",
  desc: [为了在单台服务器上托管多个网站, 我尝试了nginx、caddy和traefik, 最终选择了caddy。],
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

我购买了VPS来托管我的网站：个人主页(i.myriad-dreamin.com)和博客镜像站(cn.myriad-dreamin.com)。由于Cloudflare在我国不可用，最好在自有服务器上托管而非通过Cloudflare代理。

= 目录结构

网站目录结构如下：

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

`docker-compose.yml`包含所有运行网站的容器。`dist`目录存储各网站的静态文件。`caddy`或`nginx`拥有独立目录存放配置文件和日志。`certbot`目录包含SSL证书和certbot的webroot。

= 通过HTTP文件服务器提供`dist`内容

我不想使用`caddy`或`nginx`内置的文件服务器，需要更精细的控制（例如永久缓存字体）。因此寻找简单的HTTP文件服务器实现。照例先尝试Rust方案但未成功。

必须承认Rust并非构建Web服务的最佳（或简单）选择。虽有重型框架但不符合需求。转向轻量方案时发现它们维护不善或功能不全。最后尝试了#link("https://github.com/tiny-http/tiny-http")[tiny-http]，值得关注但仍有不足。

既然要构建网络工具，为何不用Go？我对用Go编写网络工具印象深刻。这是无可争议的良好起点，不到10行代码即可运行：

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

我还添加了`gzip`压缩等改进：

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

并修改主函数使用`Gzip`中间件：

```diff
 func main() {
   ...
-  http.Handle("/", http.FileServer(http.Dir(".")))
+  fs := http.FileServer(http.Dir("."))
+  http.Handle("/", Gzip(fs))
   ...
 }
```

再次仅用标准库构建自定义工具。最爱的语言服务器`gopls`自动完成了所有包导入。

= 需要HTTPS文件服务器吗？

四年前曾用Go构建HTTPS文件服务器，但这不是最佳实践。考虑到需设置入口控制器，SSL/TLS可在中间层处理，降低复杂度和攻击面。

= 构建HTTP文件服务器容器

若使用以下命令构建Go程序，无需自定义镜像：

```bash
CGO_ENABLED=0 go build -tags netgo -o target/file-server ./cmd/file-server
```

只需启动`alpine`容器并挂载文件服务器二进制文件即可正常工作。`docker-compose.yml`如下：

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

= 使用Nginx构建入口

我同时尝试了Caddy和Nginx，两者都不错。由于试错成本不高，先尝试了Docker官方维护的Nginx镜像：

首先在`docker-compose.yml`添加Nginx容器：

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

在`nginx/conf`目录创建配置文件`nginx.conf`：

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

注意`location /.well-known/acme-challenge/`用于certbot的HTTP挑战认证，`location /`将所有HTTP流量重定向到HTTPS。

运行`docker compose up -d nginx`启动Nginx容器，监听80和443端口。

= 使用Certbot生成SSL证书

在`docker-compose.yml`添加`certbot`容器：

```yml
services:
    certbot:
      container_name: certbot
      image: certbot/certbot
      volumes:
          - ./certbot/www:/usr/share/certbot/www:rw
          - ./certbot/ssl:/etc/letsencrypt:rw
```

执行试运行检查配置：
```bash
docker compose run --rm  certbot certonly --webroot --webroot-path /usr/share/certbot/www/ --dry-run -d orange.myriad-dreamin.com
```

移除`--dry-run`标志获取真实证书。成功后证书将存储在`certbot/ssl`目录。

= 通过Nginx提供HTTPS服务

SSL证书应位于`/usr/share/certbot/ssl/live/orange.myriad-dreamin.com`。在`nginx.conf`添加服务器块处理HTTPS流量：

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

在Docker Compose环境下，`http://homepage`通过Docker内部DNS解析到文件服务器容器。添加新站点只需复制`orange.myriad-dreamin.com`的两个服务器块并修改`server_name`。

= 恶意访问者

日志显示有恶意尝试访问`/admin`、`/login`等常见路径。幸运的是网站只有静态文件，且Nginx/Golang文件服务器足够健壮。虽然Nginx已使用20年，但仍有CVE漏洞。Caddy性能稍弱但个人网站无需高吞吐。`traefik`过于复杂，最终决定尝试Caddy。

= 使用Caddy提供HTTP服务

首先在`docker-compose.yml`添加`caddy`容器：

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

在`caddy/config`目录创建`Caddyfile`：

```caddy
:80 {
	respond "Hello World!"
}
```

运行`docker compose up -d caddy`后访问`http://localhost:80`应显示"Hello World!"。

= 通过Caddy提供HTTPS服务

Caddy可自动维护SSL证书，无需certbot。配置HTTPS服务器异常简单：

```caddy
orange.myriad-dreamin.com {
	tls x@email.com
	reverse_proxy homepage
}
```

其中`homepage`由Docker内部DNS解析。执行以下命令热重载配置：

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

比Nginx更简洁！且Caddy用Go编写，避免内存错误。

= 记录访问日志

Caddy支持纯文本和JSON格式访问日志。启用日志需在`Caddyfile`添加：

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
```

并在各站点块引用：
```diff
 orange.myriad-dreamin.com {
+  import subdomain-log orange.myriad-dreamin.com
	 tls x@email.com
	 reverse_proxy homepage
 }
```

我偏好结构化JSON日志便于解析。#link("https://github.com/pamburus/hl")[hl]是优秀的JSON日志解析工具：

```bash
$ hl caddy/log/orange.myriad-dreamin.com.jsonl
Jun 01 01:02:03.456 [INF] http.log.access.log0: handled request request.remote-ip=a.b.c.d request.remote-port="xyz" request.client-ip=a.b.c.d ...
```

实际上copilot帮助我更可读地聚合展示了访问日志。

= 代码清单

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
