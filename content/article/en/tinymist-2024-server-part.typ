#import "/typ/templates/blog.typ": *

#show: main.with(
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

In early 2024, nvarner's typst-lsp had essentially ceased development. Frustrated by this stagnation, I initiated the tinymist project.

Regarding my background, my primary programming languages were previously C++, Python, and TypeScript. I had experience developing clangd and some knowledge of LSP; I only knew basic Rust syntax and had completed typst.ts as my first project. Thus tinymist became my second Rust project.

= Community Positioning and Competition

Generally, it's best for a community to maintain a single repository for any given task. Nevertheless, I created a new repository for typst language services - a decision with both advantages and disadvantages. In retrospect, this move hasn't fractured the typst ecosystem, which is positive.

Originally, I was already a contributor to typst-lsp. During development, I identified several issues: nvarner had virtually stopped reviewing PRs, and due to some fundamental design flaws in typst-lsp, protocol-level bugs required near-total architectural overhaul. I lacked confidence and patience to persuade nvarner to rewrite almost the entire codebase.

I considered "typst-lsp" an unsuitable name; nvarner also believed it confined the project to LSP-specific development. For various reasons, I decided a unified VSCode extension and repository was necessary for language services.

Positionally, tinymist differs from typst-lsp by focusing on all editor interactions - LSP being just one component. LSP is merely implementation detail of editor protocol that shouldn't concern users.

Few notice or care about this distinction. On one hand, LSP's dominance leads many to equate language support with LSP exclusively. In reality, many interesting features fall outside LSP's scope - future possibilities include tinymist-dap and tinymist-lsif. Only tinymist-lsp directly corresponds to typst-lsp. Should nvarner return, tinymist-lsp could theoretically merge into typst-lsp, though significant PR coordination would be needed.

Conversely, knowledge tends to elitism - many experts enjoy learning these implementation details and configuring each component manually. I believe for the silent majority's convenience, all components should be unified rather than scattered across extensions. This is especially crucial since typst's userbase isn't exclusively programmers.

= LSP Framework

In practice, Rust's LSP libraries should separate into two parts: protocol format definitions (lsp-types) and protocol engine frameworks (lsp-server). Unfortunately, nvarner's choices for both proved problematic.

= LSP Protocol Format Library

lsp-types is Rust's most widely used LSP protocol library, but it's merely a subproject of a niche language. While its design suffices for most scenarios, it has drawbacks.

First, lsp-types made a critical error in version 0.95 by replacing `url::Url` with `fluent::Uri`, exposing Rust's URI/URL chaos. `url::Url` itself has flaws (e.g., adding slashes to `file://` URIs which breaks neovim). `fluent::Uri` avoids these by not supporting them - but users actually need `url::Url`'s utility methods. This essentially blocks all dependent language servers from upgrading lsp-types.

Second, I suspect lsp-types + lsp-server have performance issues in type design. For instance, all `String` instances should be replaced with `EcoString` or similar copy-reducing types - especially when servers cache data and simply copy `String`s to editors. Worse, lsp-server's use of `serde_json::Value` erases types, making zero-copy impossible. Ideally, new libraries would solve these, though intuitively they're not critical enough for immediate action.

= LSP Engine Library

For the LSP engine, nvarner chose tower-lsp, but this library does not actually respect the LSP protocol (as of 2024, this was tower-lsp's state). LSP expects sequential request processing, while tower-lsp triggers service functions out-of-order upon receiving requests. This causes the language server state to desync from the editor state shortly after startup. tower-lsp's approach also enables "fancy" service implementations, directly leading to typst-lsp requiring a complete rewrite.

How does rust-analyzer handle this? rust-analyzer uses lsp-server, a fundamentally synchronous LSP engine. Each incoming request triggers a handler that acquires `state: &mut State`.

A community member developed async-lsp for the nix-based nil project. Its interface is significantly cleaner and more elegant than lsp-server. When requests arrive, async-lsp also triggers handlers accessing global mutable state—the key difference being these handlers are async.

I wanted to use async-lsp. During integration, I again encountered Rust's chaotic aspects. Let's compare lsp-server, async-lsp, and tower-lsp in this table:

#table(
  columns: 3,
  align: center,
  [Name], [Order to Accept Requests], [Type of Handler],
  [tower-lsp], [Out of order], [`Fn() -> Fut<Req>`],
  [lsp-server], [Sequential], [`FnMut() -> Req`],
  [async-lsp], [Sequential], [`FnMut() -> Fut<Req>`],
)

Although async-lsp appears asynchronous, its awkward limitation is that handlers cannot use `.await` syntax. Instead, they must return async closures that don't reference state—a clear Rust limitation. Additionally, async-lsp makes stdio I/O asynchronous, requiring tokio's compat IO on Windows (correct me if wrong—I'm no async expert). For nix, this isn't problematic since nix runs exclusively on Unix (again, correct me if wrong—I'm not a nix user). The nil author's lack of Windows support seems reasonable.

Furthermore, I had desired changes for async-lsp to facilitate testing (now forgotten). For these reasons, despite tinymist being migration-ready for async-lsp, I retained the lsp-server wrapper. Ultimately, I hope either Rust improves async borrowing support or a better engine framework emerges.
