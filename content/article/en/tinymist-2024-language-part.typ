#import "/typ/templates/blog.typ": *

#show: main-zh.with(
  title: "Tinymist 2024 - Language Service Part",
  desc: [Thoughts on the development of tinymist, a Typst language server.],
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

Inspired by several successful projects, my recent design philosophy has shifted towards consolidating code for similar software into a single repository and minimizing excessive interface design between components. Tinymist is my first attempt at monorepo in recent years, and in practice,  this approach has boosted development efficiency in scenarios in scenarios with limited bandwidth.

== Tinymist Project Structure Design

Logically, tinymist is mainly architected by a classic frontend-backend model:
- Language service: `crates/tinymist` (Rust component) as backend, `editor/vscode` (TypeScript component) as frontend, communicating via the LSP protocol.
- Preview service: `crates/typst-preview` (Rust component) as backend, `tools/typst-preview-frontend` (TypeScript component) as frontend, using WebSockets for transport and a custom SVG-based data protocol.
- Analyzer: `crates/tinymist-query` (Rust component) as backend, `crates/tinymist` as frontend, utilizing an LSP-based interface.

A key observation is that all these frontend-backend interfaces rely on mature binary protocols, meaning the data transfer objects have stable, serializable formats. This foundation is crucial for effective decoupling and testing.

Large components consist of smaller ones, following consistent naming conventions. The language server, for instance, typically handles an LSP request as follows:

```rs
impl ServerState {
  fn serve(&mut self, req: LspRequest, id: RequestId) {
    let snapshot = change_and_prepare(self, req) // mut
    spawn(async move {
      let mut ctx = LocalContext(snapshot);
      let resp = handle(&mut ctx, req).await;
      ctx.send(id, resp);
    });
  }
}
```

The guiding principle for Tinymist's design is local mutability with shared (global) immutability, an approach I've found to be particularly well-suited for building reliable language servers.

=== Mutable Global State

`ServerState` is mutable, meaning the server starts of all LSP requests sequentiallly. However, this does not imply full sequentialization. `ServerState` only quickly updates the global state based on the request and creates a snapshot (or lock) of part of the state before entering the time-consuming phase. Since snapshots can be safely shared among threads, by 2025, tinymist ensures that requests do not block each other, especially time-consuming requests not blocking latency-sensitive ones.

The language server handles with a mutable `ServerState`. It starts to process all LSP requests sequentially, but this doesn't imply full sequentialization. `ServerState` quickly updates the global state based on a request and creates a snapshot (or lock) of the a smaller part of relevant state before any time-consuming work begins. Because these snapshots are thread-safe, Tinymist ensures that requests, especially latency-sensitive ones, are not blocked by longer-running operations.

`ServerState` aggregates all server states. For example:
- `ProjectState` manages the state of all projects, with its snapshot being `LspWorld`. Those familiar with Typst will recognize typst `World`s hold all Typst compilation resources, serving as the surface between Typst tasks and the underlying OS.
- `PreviewState` manages the state of all preview tasks. Launching a preview task spawns a Tokio task and returns an MPSC channel as a "snapshot." This Tokio task holds its own mutable state and handles preview serve requests from various threads.
-  All other states are concretely and compositely defined within `ServerState`.

This structure allows developers to understand global state management and quickly locate related logic by examining the state code directly. This differs from many projects that prefer using abstract classes and interfaces to hide implementations.

Conceptually, `ServerState` is viewed as a large monitor procedure. When starting to serve a request, it simply locks and modifies all substates, quickly acquiring fine-grained locks and releasing the global state. Tinymist then executes time-consuming tasks on these fine-grained locks to maximize parallelism.

This design is inspired by Linux kernel, and we simplified a bit, that we increase the granularity of the initial state lock. Linux gradually locks parts of the state for a syscall, risking deadlocks and TOCTOU, whereas tinymist locks all states first.

Although tinymist's simplification has the drawback of reducing throughput, this weakness is mitigated in the language server scenario. language servers do not require extremely high concurrency, and tinymist introduces a snapshot mechanism. In practice, this model of tinymist has proven highly effective for building reliable services. I believe that with optimization, this model can handle requests at 10k or even 100k OP/s. For reference, tinymist v0.14 serves LSP requests at 11.04k OP/s in smoke tests.

=== Mutable Background State

`PreviewState` well reflects how tinymist handles complex lifecycle tasks. A preview session involves a user starting a preview, sending multiple requests during its lifetime, and finally terminating it.

When a user initiates a preview, the request reaches `ServerState`, which creates a `PreviewActor`. The actor runs in the background and holds state mutably, and also serves all preview requests sequentiallly, essentially mirroring the same Actor design pattern as `ServerState`.

In terms of lifecycle, the lifecycle of a single preview request is strictly contained within the `PreviewActor` lifecycle, and the `PreviewActor` lifecycle is strictly contained within the `ServerState` lifecycle. Like LSP requests, preview service requests also leverage the large monitor and snapshot mechanism to ensure safe modification of global state while maintaining high concurrency.

=== Mutable Local State

For analysis requests, Tinymist creates a `LocalContext` on the local stack:

```rs
let mut ctx = LocalContext(snapshot);
```

This context object remains mutable. When analysis requires caching, the context first queries its local cache and then pulls from the global cache if local cache missing. This is inspired by MLIR's parametric storage design.

== Typst Tool Design

Tinymist is not only a LSP server but an integrated service for Typst, or referred to as a Typst toolchain. Currently, there are many related tools:
- `tinymist lsp`, LSP protocol service.
- `tinymist preview`, preview service.
- `tinymist dap`, DAP protocol service.
- `tinymist test`, unit or visual tests.
- `tinymist cov`, coverage tests.
- `crityp`, performance testing (Benchmark).
- `typlite`, converts typst to other markup languages like markdown, tex, docx.

Despite the large number of tools, tinymist's tool library is relatively simple. First, tools share CLI input parser:

```rs
#[derive(clap::Parser)]
pub struct CompileOnceArgs { ... }
```

This is a struct that implements command-line parsing, fully compatible with `typst-cli`, and also implements `WorldProvider` trait:

```rs
pub trait WorldProvider {
  fn resolve(&self) -> Result<LspUniverse>;
}
```

`LspUniverse` is a mutable struct. Developers can easily modify compiler resources and create an `LspWorld` snapshot, which can be safely shared across threads.

```rs
let verse = CompileOnceArgs::parse().resolve();
let doc = typst::compile(&verse.snapshot());
```

To add custom command-line arguments, one can use clap flatten:

```rs
#[derive(clap::Parser)]
pub struct ToolArgs {
  #[clap(flatten)]
  compile: CompileOnceArgs;
  #[clap(flatten)]
  extra: ToolExtraArgs;
}
```

This makes it very easy to build and start custom Typst tasks:

```rs
let ToolArgs { compile, extra } = ToolArgs::parse();
let verse = compile.resolve();
run_tool(verse, extra);
```

I believe our design here well follows the principle of subtraction:
- Command-line arguments are fully compatible with `typst-cli`, allowing all tools to smoothly upgrade interfaces along with `typst-cli` and reducing user learning burden.
- Coupling clap into the interface saves design effort, as the first step is naturally parsing the command line, then guiding developers to use concepts like Universe.
- It still follows to the "local mutable, shared (global) immutable" design mentioned earlier, enabling efficient multi-threaded tasks.

== tinymist.lock Design

The `tinymist.lock` file is a *compilation history database* that records compilation events within a workspace. Inspired by C++'s `compile_commands.json` and Rust's lock file mechanism, its primary goal is to help the language server comprehend the complex relationships between documents and source files in multi-file projects, particularly by solving the challenge of automatic "main file" detection.

The project management mode is controlled by the `tinymist.projectResolution` setting. The default, `singleFile`, treats each Typst file as an independent document, neither generating nor using lock files, which is ideal for single-file or small projects. The alternative, `lockDatabase`, mimics Rust's project management by tracking compilation and preview history. This history is stored in the `tinymist.lock` file, enabling Tinymist to automatically select the main file based on past activity.

=== Core Structures: InputSpec, OutputSpec, and RouteSpec

Compatible with `typst-cli`, the input is split into three parts: `InputSpec` determines how to create an `LspUniverse`, `OutputSpec` determines how to execute a Typst task, and `RouteSpec` sets the priority of the entry.

With multiple input sources, Tinymist can intelligently infer project inputs:
- CLI commands: triggered via `tinymist compile/preview --save-lock`.
- LSP commands: pushed from the editor client.
- External tools: such as testing tools.

Tinymist will set up multiple databases with different duability and priority levels.

- In-memory database, automatically learning all input sources during this language service lifecycle. The database is destroyed when the service terminates.
- File database, where a `tinymist.lock` file can be saved in the project root, allowing multiple processes to share information about project inputs.

Summary:
- It avoids burdening the user with manual configuration, allowing users to update the lock file through "successful" compilations, such as `typst compile` (`tinymist compile`).
- The format remains fully compatible with `typst-cli`'s command-line interface, ensuring stability. This also helps other tool developers quickly learn the format and making code update the lock.
- It stores minimal data on the filesystem, favoring lightweight, multi-process collaboration.

== Textmate Grammar Support

Typst's Textmate grammar is quite challenging, as Typst is very context-sensitive while Textmate is regex-based and only supports `begin` and `while` patterns. However, we have finished a grammar implementation that can parse all packages on `typst/packages`, with some interesting principles:
-  We achieved 100% accuracy by giving up on recognizing some syntactic structures.
- We enabled some context-sensitive parsing by assuming well-formed syntax. In a couple of extreme cases, we use scripts to generate regular expressions that look ahead 6 characters for parsing.

This Textmate grammar has now been used by GitHub for Typst syntax highlighting.
