
#import "/typ/templates/mod.typ": sys-is-html-target
#import "@preview/rubby:0.10.2": get-ruby
#import "@preview/cades:0.3.1": qr-code

#let ruby = if sys-is-html-target {
  (a, b) => html.elem("span", attrs: (style: "display: inline-block; margin-top: -0.3em"), html.elem(
    "ruby",
    [#b#html.elem(
        "rp",
        "(",
      )#html.elem(
        "rt",
        a,
      )#html.elem("rp", ")")],
  ))
} else {
  get-ruby(
    size: 0.5em, // Ruby font size
    dy: 0pt, // Vertical offset of the ruby
    pos: top, // Ruby position (top or bottom)
    alignment: "center", // Ruby alignment ("center", "start", "between", "around")
    delimiter: "|", // The delimiter between words
    auto-spacing: true, // Automatically add necessary space around words
  )
}

#let align-center = if sys-is-html-target {
  content => html.elem("div", attrs: (style: "text-align: center"), content)
} else {
  content => align(center, content)
}
