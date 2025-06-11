#import "/typ/templates/blog.typ": *
#show: main-zh.with(
  title: "Temperament",
  desc: [Some mathematics about temperament.],
  date: "2025-05-12",
  tags: (
    blog-tags.music-theory,
  ),
)

= 五度相生律#footnote[#link("https://zh.wikipedia.org/wiki/%E4%BA%94%E5%BA%A6%E7%9B%B8%E7%94%9F%E5%BE%8B")[维基百科：五度相生律]]

从一个起点音#footnote[在FL Studio等宿主软件中，这个音一般是A，且$A=440 med "Hz"$]出发，毕达哥拉斯发现比例为$1:2$的音程最为和谐，这个比例被称为纯八度。其次，比例为$2:3$的音程也很和谐，这个比例被称为纯五度。其中的规律是：比例越简单的音程越和谐。若我们令$r=3\/2$则有：

#let nodes = ([C], [D], [E], [F], [G], [A], [B], [C#super[2]])
#let rels = ($C$, $r^2 C \/ 2$, $r^2 D \/ 2$, $2 C \/ r$, $r C$, $r D$, $r E$, $2 C$)

#let fig = {
  import fletcher: *
  diagram({
    for (i, n) in nodes.enumerate() {
      node((i, 0.5), n, stroke: none)
    }
    for (i, n) in rels.enumerate() {
      node((i, 0), n, stroke: none)
    }
  })
}

#figure(
  code-image(fig),
  caption: "五度相生律",
)

= 十二平均律

五度相生律很好，但是它并不适合传统作曲和演奏。特别是C♯与D♭的音高不同，给升调、降调以及和弦的推导带来了困难。为了解决这个问题，音乐家们发明了十二平均律。它的原理是将一个八度音程分成12个相等的音程，每个音程的比例为$2^(1\/12)$。在这种情况下，令$r$的值为$2^(1\/12)$，十二平均律则为：

#let nodes = ([C], [D], [E], [F], [G], [A], [B], [C#super[2]])
#let rels = ($C$, $r^2 C$, $r^4 C$, $r^5 C$, $r^7 C$, $r^9 C$, $r^11 C$, $r^12 C$)

#let fig = {
  import fletcher: *
  diagram({
    for (i, n) in nodes.enumerate() {
      node((i, 0.5), n, stroke: none)
    }
    for (i, n) in rels.enumerate() {
      node((i, 0), n, stroke: none)
    }
  })
}

#figure(
  code-image(fig),
  caption: "十二平均律",
)

十二平均律的代价是其音程并不完美，例如纯五度变为了$1.4983 C$而非$1.5 C$。
