#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "维护 GCC",
  desc: [一些全局维护 gcc 的有用命令。],
  date: "2025-05-12",
  tags: (
    blog-tags.programming,
    blog-tags.linux,
    blog-tags.dev-ops,
  ),
)

= 列出 G++ 包

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

= 使用特定版本的 gcc

```bash
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7
```

= 检查已配置的 gcc 版本

```bash
sudo update-alternatives --config gcc
sudo update-alternatives --config g++
```

= GNU 工具链目录结构

- `bin` - 可执行文件
- `include` - 头文件
- `lib` - 库文件
- `libexec` - 内部使用的可执行文件

目录结构很重要，因为 `gcc` 会根据相对于 `which gcc` 的路径在这些目录中查找文件。
