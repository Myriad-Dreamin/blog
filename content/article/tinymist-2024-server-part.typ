#import "/typ/templates/blog.typ": *

#show: main-zh.with(
  title: "Tinymist 2024 - 语言服务器部分",
  desc: [关于 tinymist，一个 typst 的语言服务器的开发思考。],
  date: "2025-11-09",
  tags: (
    blog-tags.programming,
    blog-tags.tinymist,
    blog-tags.software,
    blog-tags.software-engineering,
    blog-tags.compiler,
    blog-tags.typst,
  ),
)

在2024年初的时候，由nvarner编写的typst-lsp已经基本停止开发。怒其不争，遂开发了tinymist。

就个人背景，此前我的主要编程语言是C++，Python和TypeScript；并已经有开发过clangd的经验，学过一些lsp相关的知识；我只学过简单的rust语法，并上手了typst.ts作为第一个项目。也就是说tinymist是我的第二个rust项目。

== 社区定位与竞争

一般来说，一件事情整个社区最好只有一个仓库，我还是换了一个仓库开发针对typst的语言服务，这里面有好有坏。从结果来看，我们的这一举措并没有对typst生态造成破坏，这便很好了。

最初，我已经是typst-lsp的贡献者了。在开发的过程中，我发现很多问题。首先nvarner已经几乎不审PR了。其次，由于typst-lsp的一些错误决定，一些协议上的bug已经到了需要完全调整架构的程度，我没有信心和耐心劝说nvarner修改typst-lsp几乎所有代码。

我认为typst-lsp这个名字并不好，nvarner也认为取了这个名字typst-lsp就只专注于lsp相关开发。出于一些想法，我认为对于语言服务，我们要提供一个统一的vscode扩展和仓库。

在定位上，tinymist与typst-lsp的区别是，tinymist关注与编辑器的所有交互，lsp只是其组成部分之一。lsp只是用户无需关注的与用户交互的编辑器协议细节。

不多的人注意或在意这一点，一方面因为lsp势大，许多人认为language support等于lsp。实际上，还有很多其他有趣的功能不被lsp囊括。例如，将来我们还能引入tinymist-dap，tinymist-lsif等。tinymist-lsp才是等价于typst-lsp的部分。如果nvarner最终能回来，tinymist-lsp应该能合并到typst-lsp，尽管这需要相当长的时间来协调PR。

另一方面，用户的知识有精英化的趋势，许多精英更喜欢学习这些无关紧要的细节，并享受为其一一配置的过程。而我认为，为了方便不发声的大部分群体，所有的这些最终都要统一组装起来交给用户，而非散落成很多扩展让用户一一安装。这一点因typst的目标群体并非都是程序员而变得尤为重要。

== LSP框架

在事实上，rust的lsp相关库应当分为两部分。一部分是lsp协议的格式，这对应于lsp-types；另一部分是lsp协议的引擎框架，这对应于lsp-server。不幸的是，nvarner选的这两方面的库都中了招。

== LSP协议格式库

lsp-types是目前最广泛使用的关于lsp协议格式的库，但它只是一个小众语言的子项目。它目前的设计已经足够几乎所有场景的使用，但也有不好的地方。

首先，lsp-types曾在0.95做出过错误的决定，将`url::Url`替换成了`fluent::Uri`，揭露了rust在uri/url这个几乎是最常用格式上的混沌。`url::Url`本身就有许多毛病。比如在解析`file://`时会给它加一个斜杠，而neovim因此变得红温。`fluent::Uri`则表示，这些我干脆都不支持，就没有bug了。但是大家实际上是需要在`url::Url`上的许多方便方法（method）的。这直接使得几乎所有依赖lsp-types的语言服务无法升级lsp-types到更高版本。

其次，我觉得lsp-types+lsp-server在类型和格式的设计上有性能问题。比如，我认为lsp-types里所有的`String`都应该替换成`EcoString`等减少内存拷贝的特殊字符串类型。尤其是当在语言服务器有缓存的时候，许多`String`都只是简单拷贝并响应给编辑器。当然，简单观察后，我还发现由于lsp-server使用了`serde_json::Value`擦除类型，零拷贝已然成为了不可能。总的来看，我希望有新的lsp库来解决这些问题。尽管从直觉上，这并非性能上的主要问题，使得我个人不会急迫需要这方面的改进。

= LSP引擎库

在lsp引擎上，nvarner的选择是tower-lsp，但是这个库事实上并没有尊重lsp协议（2024年的时候，tower-lsp的情况如此）。lsp在时序上希望你能保证按顺序处理请求，而tower-lsp收到请求上会乱序触发上层service的函数。这会导致language server状态在启动后一段时间与编辑器状态desync。tower-lsp的这一做法也使得允许上层service有一些“fancy”的写法，直接导致typst-lsp需要完全重写。

rust-analyzer是怎么做的呢。rust-analyzer使用了lsp-server，这是一个底层完全同步的lsp引擎。每当有一个请求到来，都会触发一个获得`state: &mut State`的handler。

一位群友为nix写的nil用了这位群友自研的async-lsp。其接口要比lsp-server整洁和neat的多。每当有一个请求到来，async-lsp也会触发获得全局可变状态的handler，区别是这个handler是async的。

我是希望使用async-lsp的。在接入的过程中，再一次挖掘到了rust的混沌之处。我们做一个表格，lsp-server，async-lsp，tower-lsp的区别如下：

#table(
  columns: 3,
  align: center,
  [Name], [Order to Accept Requests], [Type of Handler],
  [tower-lsp], [Out of order], [`Fn() -> Fut<Req>`],
  [lsp-server], [Sequential], [`FnMut() -> Req`],
  [async-lsp], [Sequential], [`FnMut() -> Fut<Req>`],
)

虽然async-lsp看似async了，但是别扭之处在于，它的handler无法使用`.await`语法，取而代之，必须返回一个不引用state的async闭包。这显然是rust的局限性。其次async-lsp将stdio的读写异步化了，而在windows上，这必须要借助tokio的compat IO（correct me if I'm wrong，因为我不是async专家）。对于nix，这并非问题，因为nix只会在unix上运行（correct me if I'm wrong，因为我不是nix用户）。我觉得nil的作者不会为windows用户买单属于合情合理。

另外，为了方便测试，我有一些希望async-lsp改变的东西（目前已经忘了）。出于以上原因，尽管tinymist已经完全做好了迁移到async-lsp的准备，我还是选择了继续保留对lsp-server的包装。总的来说，我希望将来要么rust改进对async借用的支持，要么有一个更好的引擎框架。
