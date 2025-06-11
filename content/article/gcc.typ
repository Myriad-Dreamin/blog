#import "/typ/templates/blog.typ": *
#show: main-en.with(
  title: "Maintaining GCC",
  desc: [Some useful commands to maintain gcc globally.],
  date: "2025-05-12",
  tags: (
    blog-tags.programming,
    blog-tags.linux,
    blog-tags.dev-ops,
  ),
)

= List G++ Packages

```bash
sudo apt list "gcc-*" | grep -P "gcc-\d+\/"
sudo apt list "g++-*" | grep -P "g++-\d+\/"
```

= build-essential

```bash
sudo apt-get install build-essential
```

= update-alternatives

```bash
sudo apt-get install update-alternatives
```

= Using specific version of gcc

```bash
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7
```

= Checking versions of configured gcc

```bash
sudo update-alternatives --config gcc
sudo update-alternatives --config g++
```

= GNU Toolchain Directory Layout

- `bin` - Executable files
- `include` - Header files
- `lib` - Libraries
- `libexec` - Executable files for internal use

The directory layout is important, because `gcc` will find files in these directories by path relative to `which gcc`.
