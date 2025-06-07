#import "/typ/templates/blog.typ": *
#show: main.with(
  title: "Temperament",
  desc: [Some mathematics about temperament.],
  date: "2025-05-12",
  tags: (
    blog-tags.music-theory,
  ),
)

= Pythagorean Tuning#footnote[#link("https://zh.wikipedia.org/wiki/%E4%BA%94%E5%BA%A6%E7%9B%B8%E7%94%9F%E5%BE%8B")[Wikipedia: Pythagorean tuning]]

Starting from a base note#footnote[In DAWs like FL Studio, this note is usually A, and $A=440 med "Hz"$], Pythagoras discovered that the interval with ratio $1:2$ is most harmonious, called the perfect octave. Next, the interval with ratio $2:3$ is also harmonious, called the perfect fifth. The principle is: simpler ratios yield more harmonious intervals. If we let $r=3\/2$ then:

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
  caption: "Pythagorean Tuning",
)

= Twelve-Tone Equal Temperament

Pythagorean tuning works well but isn't ideal for traditional composition and performance. Specifically, C♯ and D♭ have different pitches, causing difficulties in transposition, modulation, and chord derivation. To solve this, musicians developed twelve-tone equal temperament. Its principle is dividing an octave into 12 equal intervals, each with ratio $2^(1\/12)$. Letting $r=2^(1\/12)$, we get:

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
  caption: "Twelve-Tone Equal Temperament",
)

The trade-off is imperfect intervals, e.g. the perfect fifth becomes $1.4983 C$ instead of $1.5 C$.
