#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "Typst 语法",
  desc: [Typst 语法列表，用于渲染测试。],
  date: "2025-05-27",
  tags: (
    blog-tags.programming,
    blog-tags.typst,
  ),
)

= 原始块

这是一个内联原始块 `class T`。

这是一个内联原始块 ```js class T```。

这是一个长内联原始块 ```js class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {};```。

Js 语法高亮由 syntect 处理：

```js
class T {};
```

Typst 语法高亮由内部特殊处理：

```typ
#let f(x) = x;
```
