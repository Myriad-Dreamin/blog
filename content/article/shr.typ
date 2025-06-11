
#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "Say Goodbye to Space Sniffer",
  desc: [I wrote a fast tool to replace space sniffer.],
  date: "2025-05-20",
  tags: (
    blog-tags.programming,
    blog-tags.software,
    blog-tags.tooling,
    blog-tags.dev-ops,
  ),
)

#link("https://github.com/redtrillix/SpaceSniffer")[Space Sniffer] 是一个很不错的工具，但是最近我不满足于他较慢的速度，自己写了一个扫描工具。发布页面在#link("https://github.com/Myriad-Dreamin/shr/releases")[这里]。

= Backend API: Event Iterator

我将shr分为了前端和后端。后端接受参数，扫描文件系统，返回一个迭代器，每项是一个事件更新，这样前端就能不断从迭代器中获取事件，更新UI。

= CLI Frontend

#link("https://github.com/Myriad-Dreamin/shr/tree/main/crates/shr-cli")[`shr-cli`]是一个类`du`的命令行工具，使用了`shr`的后端API。它支持所有主流平台。

= Slint GUI Frontend

#link("https://github.com/Myriad-Dreamin/shr/tree/main/crates/shr-browser")[`shr-browser`]是一个Slint GUI，使用了`shr`的后端API。出乎意料的是，它也支持所有主流平台。

#figure(code-image(image("shr/gui.png")), caption: "Slint GUI")

= 性能

在我的机器上，`shr-browser`比已有的工具`dust`快了大约6.1% (77秒对比82秒)。似乎并没有明显优势。

= 可能的改进

`shr`的IO瓶颈在于`std::fs::read_dir`，可能可以使用比tokio更好的后端，例如compio。

`shr`的内存瓶颈在于保存了太多完整路径。实测5000k个文件（800G）时，内存占用在1.5GB左右。这意味着，45G的内存可以支持32TB的完整预览，已经基本满足扫全盘的需求了。未来如果有可能，会有限改进这一点。

= 后记

已经使用过几次了，速度很快，UI也很流畅。但是每次扫盘的时候，都主要是扫描到大量占用的cargo cache。感觉我只是需要一个好的cargo缓存清理工具。
