#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "我的无后端博客搭建方案",
  desc: [通过 GitHub Pages 和 Cloudflare 配置博客。],
  date: "2025-05-21",
  tags: (
    blog-tags.dev-ops,
    blog-tags.misc,
  ),
)

= 使用 Cloudflare DNS

首先，我将域名的名称服务器更改为 Cloudflare。通过运行以下命令测试名称服务器是否设置正确：

```bash
λ dig example.com +nostats +nocomments +nocmd
;example.com.            IN      A
example.com.     600     IN      SOA     ignat.ns.cloudflare.com. dns.cloudflare.com. 2373316940 10000 2400 604800 1800`
```

= 在 GitHub 上验证域名所有权

在"设置 > Pages"中，添加自定义域名`example.com`，并通过在 Cloudflare DNS 设置中添加 TXT 记录验证域名所有权。

= 配置 GitHub Pages

在 GitHub 仓库设置中，将自定义域名改为`www.example.com`。接着前往 Cloudflare DNS 设置，添加一条指向`myriad-dreamin.github.io`的`www` CNAME 记录。注意该记录应设为*"仅DNS"而非"代理"*。运行以下命令测试名称服务器配置：

```bash
λ dig www.example.com +nostats +nocomments +nocmd
;www.example.com.                IN      A
www.example.com. 300     IN      CNAME   myriad-dreamin.github.io.
myriad-dreamin.github.io. 3600  IN      A       x.x.x.x
```

最终博客应可通过`www.example.com`访问。
