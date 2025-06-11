#import "/typ/templates/blog.typ": *
#show: main-en.with(
  title: "Typst Syntax",
  desc: [List of Typst Syntax, for rendering tests.],
  date: "2025-05-27",
  tags: (
    blog-tags.programming,
    blog-tags.typst,
  ),
)

= Raw Blocks

This is an inline raw block `class T`.

This is an inline raw block ```js class T```.

This is a long inline raw block ```js class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {}; class T {};```.

Js syntax highlight are handled by syntect:

```js
class T {};
```

Typst syntax hightlight are specially handled internally:

```typ
#let f(x) = x;
```

= Images

/// Parses a `.env` file into a dictionary.
/// TODO: multiple-line values are not supported.
///
/// - data (str): The content of the `.env` file.
/// -> dictionary
#let parse-env(data) = {
  let lines = data.split("\n").map(it => it.trim()).filter(it => it != "" and not it.starts-with("#"))
  let env = (:)

  lines
    .map(line => {
      let matched = line.match(regex("^([^=]+)=(?:\"([^\"]*)\"|(.*))$"))
      let (key, v1, v2) = matched.captures
      (key, v1 + v2)
    })
    .to-dict()
}

// Gets url-base from the `.env` file
#let url-base = {
  // todo: what if I would like use other configuration like `.env-production`
  let env-data = parse-env(read("/.env"))

  let url-base = env-data.at("URL_BASE", default: "")
  if not url-base.ends-with("/") {
    url-base = url-base + "/"
  }
  url-base
}

// Resolves the path to the image source
#let resolve(path) = (
  path.replace(
    // Substitutes the paths with some assumption.
    regex("^[./]*/public/"),
    url-base,
  )
)

#show image: it => {
  html.elem(
    "img",
    attrs: (
      // Sets src
      src: resolve(it.source),
      // This is only set for good look in the follow tests.
      style: "width: 33%; display: block; margin: auto;",
    ),
  )
}

// #image("../../public/favicon.svg")

// #image("/public/favicon.svg")
