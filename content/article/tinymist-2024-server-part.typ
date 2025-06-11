#import "/typ/templates/blog.typ": *

#show: main-zh.with(
  title: "Tinymist 2024 - Language Server Part",
  desc: [Some thoughts on the development of tinymist, a language server for typst.],
  date: "2025-05-23",
  tags: (
    blog-tags.programming,
    blog-tags.tinymist,
    blog-tags.software,
    blog-tags.software-engineering,
    blog-tags.compiler,
    blog-tags.typst,
  ),
)

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
