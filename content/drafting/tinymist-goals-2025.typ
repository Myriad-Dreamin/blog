#import "/typ/templates/blog.typ": *
#show: main-en.with(
  title: "Tinymist Project Goals for 2025",
  desc: [What has been made in 2025 and what will be made in 2026 in Tinymist.],
  date: "2025-11-09T22:55:57+08:00",
  tags: (
    blog-tags.programming,
    blog-tags.tinymist,
    blog-tags.software,
    blog-tags.software-engineering,
    blog-tags.compiler,
    blog-tags.typst,
  ),
)

#let aiww = [╮(′～‵〞)╭]
#let aiww = if sys-is-html-target { html.elem("span", attrs: ("style": "font-family: Microsoft YaHei, Arial, sans-serif;"), aiww) } else {aiww}

Typst v0.14 was released in October 24, 2025 and tinymist quickly followed up. Luckily, as what we believed, tinymist smoothly moved to typst v0.14. Since typst may not publish v0.15 in the end of 2025 (#aiww), I would like to make a summary of what has been made in 2025 and what will be made in 2026 in Tinymist.

= Maintainer/Developer Status

I added 4 new maintainers to the project this year. They are:
// - @nvarner, the original author of typst-lsp.
// - @v01d, the author of typst-preview.
// - @huyu, the author of tinymist-query.
// - @jeffersonqin, the author of tinymist-test.

5 contributors has made major contributions to the project this year:
// - @nvarner, the original author of typst-lsp.
// - @v01d, the author of typst-preview.
// - @huyu, the author of tinymist-query.
// - @jeffersonqin, the author of tinymist-test.
// - @jeffersonqin, the author of tinymist-test.

= Health Status

#let issues = json("/scripts/content/tinymist-issues-2024-2025-trim.json");

#let bugs = issues.filter(issue => issue.labels.any(label => label == "bug"));
#let open-bugs = bugs.filter(issue => issue.state == "open");
#let earliest-open-bug = {
  let it = open-bugs.first();
  for issue in open-bugs {
    if issue.number < it.number {
      it = issue;
    }
  }
  it
}

#let iso-parser = regex("(\\d{4})-(\\d{2})-(\\d{2})T\\d{2}:\\d{2}:\\d{2}Z");
#let open-created-at = earliest-open-bug.created_at.match(iso-parser);
#let month = (
  "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"
).at(int(open-created-at.captures.at(1)));

#let stat(issues, at: "created_at") = {
  let buckets = (:)
  for issue in issues {
    let date = issue.at(at);
    if date == none {
      continue;
    }
    let ymd = date.match(iso-parser).captures;
    let key = ymd.at(0) + "-" + ymd.at(1);
    buckets.insert(key, buckets.at(key, default: 0) + 1);
  }

  let acc = 0;
  for (m, year) in (range(3, 13).zip(("2024",) * 10) + range(1, 12).zip(("2025",) * 11)) {
    let key = year + "-" + (if m < 10 { "0" } else { "" }) + str(m);
    let value = buckets.at(key, default: 0);
    acc += value;
    buckets.insert(key, acc);
  }

  buckets.pairs().sorted()
}

#let bugs-summary = stat(bugs, at: "created_at");
#let closed-bugs-summary = stat(bugs, at: "closed_at");

There are #bugs.len() bugs opened since 2024. #(bugs.len() - open-bugs.len()) bugs are closed and #open-bugs.len() bugs are still open. Among all opened bug, the earliest one is "#earliest-open-bug.title", which was opened on #month #open-created-at.captures.at(2), #open-created-at.captures.at(0).

#align(center, table(
  columns: 3,
  align: center,
  "Month", "Opened Bugs", "Closed Bugs",
..(..bugs-summary.zip(closed-bugs-summary)).map(it => (..it.at(0),it.at(1).at(1)).map(str)).flatten()
))

= Typst as an Embedded Script

== Custom Paste Handler

== Package-Specific Code Lenses and Code Actions

== Debouncing compilation

== Postprocessing artifacts

= Preview Service

== Preview Theme

== Browsing and Background Preview

== Rendering in WebWorker

== Periscope Preview

= Package Docs

== Docstring Syntax

== LSIF Index

== Hover Support

= Langauge Service

== Syntax-Only LSP Request Handling

== Context-Sensitive Code Analyzer and Type Checker

= `tinymist.lock`

== Initial Support

== In-Memory Database

== File Database

= Typst Testing and Benchmarking

== Unit Testing

== Coverage Testing

== Benchmarking

= Building and Testing

== CI/CD

== Attestation

== Code Signing

== Compiling to Wasm

== Neovim as a Spec Editor -- Integration Tests

