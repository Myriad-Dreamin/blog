#import "/typ/templates/blog.typ": *
#show: main.with(
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

#link("https://github.com/redtrillix/SpaceSniffer")[Space Sniffer] is a great tool, but recently I became dissatisfied with its slow speed and developed my own scanning tool. The release page is #link("https://github.com/Myriad-Dreamin/shr/releases")[here].

= Backend API: Event Iterator

I divided shr into frontend and backend. The backend takes parameters, scans the filesystem, and returns an iterator where each item is an event update, allowing the frontend to continuously fetch events from the iterator to update the UI.

= CLI Frontend

#link("https://github.com/Myriad-Dreamin/shr/tree/main/crates/shr-cli")[`shr-cli`] is a `du`-like command-line tool using shr's backend API. It supports all major platforms.

= Slint GUI Frontend

#link("https://github.com/Myriad-Dreamin/shr/tree/main/crates/shr-browser")[`shr-browser`] is a Slint GUI utilizing shr's backend API. Surprisingly, it also supports all major platforms.

#figure(code-image(image("../shr/gui.png")), caption: "Slint GUI")

= Performance

On my machine, `shr-browser` is about 6.1% faster than the existing tool `dust` (77 seconds vs 82 seconds). This doesn't seem to be a significant advantage.

= Potential Improvements

The IO bottleneck in `shr` lies in `std::fs::read_dir`; potentially a better backend like compio could replace tokio.

The memory bottleneck comes from storing too many full paths. Testing with 5000k files (800GB) showed ~1.5GB memory usage. This means 45GB RAM could support previewing 32TB – sufficient for full-disk scanning. Future improvements may prioritize this.

= Afterword

I've used it several times – fast and smooth UI. But during scans, I mostly encounter massive cargo cache usage. Feels like I just need a good cargo cache cleaner.
