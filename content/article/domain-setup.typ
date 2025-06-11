#import "/typ/templates/blog.typ": *
#show: main-en.with(
  title: "My Blog Setup without Backend",
  desc: [Configuring a blog via GitHub Pages and Cloudflare.],
  date: "2025-05-21",
  tags: (
    blog-tags.dev-ops,
    blog-tags.misc,
  ),
)

= Using Cloudflare DNS

First, I change the nameservers of my domain to Cloudflare. I then test that the nameservers are set correctly by running the following command:

```bash
λ dig example.com +nostats +nocomments +nocmd
;example.com.            IN      A
example.com.     600     IN      SOA     ignat.ns.cloudflare.com. dns.cloudflare.com. 2373316940 10000 2400 604800 1800`
```

= Verifying the ownership of the domain on GitHub

Under "Setting > Pages", I add the custom domain `example.com` and verify the ownership of the domain by adding a TXT record in Cloudflare DNS settings.

= Configuring the GitHub Pages

In the GitHub repository settings, I change the custom domain to `www.example.com`. Then, goto the Cloudflare DNS settings and add a CNAME record for `www` pointing to `myriad-dreamin.github.io`. Noted that the record shouldn't be *"Proxied" but "DNS Only"*. Test that the nameservers are set correctly by running the following command:

```bash
λ dig www.example.com +nostats +nocomments +nocmd
;www.example.com.                IN      A
www.example.com. 300     IN      CNAME   myriad-dreamin.github.io.
myriad-dreamin.github.io. 3600  IN      A       x.x.x.x
```

The blog finally should be accessible at `www.example.com`.
