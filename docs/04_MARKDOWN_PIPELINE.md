# 04 · Markdown pipeline

The pipeline is the product. Every stage is defensive (rule 9), and every
stage that lives in `core/markdown/` is pure Dart (rule 3): the pipeline ends
at a `DocModel`. Turning that into widgets is the reader's job — see doc 02,
"The seam".

## Stages

```
  core/markdown/  (pure Dart)                    │  features/reader/rendering/
  ───────────────────────────────────────────────┼───────────────────────────
  bytes → decode → front-matter split            │
        → [mdx sanitize] → rewrite block HTML    │
        → parse → DocModel  ───────────────────  ┼──→ MarkdownRenderer.build
                    (outline · slugs · blocks)   │          → widgets
```

1. **Decode.** UTF-8, BOM stripped. Invalid sequences decode lossily
   (U+FFFD) and raise a non-blocking notice bar.
2. **Front-matter.** A leading `---` fenced block is lifted out before
   parsing and shown as a collapsible key/value panel (setting: collapsed /
   expanded / hidden). YAML that fails to parse as simple `key: value` lines
   is shown raw inside the panel — never fed to the renderer, never fatal.
   Rules, decided when the splitter was written:
   - The opening `---` must be the whole of line one, unindented.
   - The first later line that is exactly `---` or `...` closes it.
   - **No closing fence means no front matter**, and the document is parsed
     whole. Swallowing an entire document because it opened with a thematic
     break is exactly the failure rule 9 exists to prevent.
   - A non-blank line that is not an unindented `key: value` — a nested key,
     a YAML comment, a bare list item — makes the block `parsed: false`. That
     selects the raw view of the panel; it is not an error.
   - A repeated key keeps the last value; the panel shows keys in source order.
3. **MDX sanitize** (`.mdx` only — by extension, no sniffing). See below.
4. **Rewrite block HTML.** Every top-level HTML block becomes a fenced code
   block carrying the reserved info string `html marklens-raw`. See the HTML
   policy below for why this cannot be done downstream.
5. **Parse.** Through the pure-Dart `markdown` package (Dart team), with the
   flavour pinned in `core/markdown/markdown_flavor.dart`:
   `ExtensionSet.gitHubFlavored` and `encodeHtml: false`. **The renderer reads
   the same constant** — if the two parses were configured differently the
   block segmentation would diverge and every scroll target would be wrong.
   One parse yields the AST, the heading **outline** with its slugs, and the
   **block index**. The AST carries no positions, so the parse is driven with
   position-recording *subclasses* of the package's own block syntaxes;
   subclasses rather than wrappers, because `BlockParser`, `SetextHeaderSyntax`
   and `HtmlBlockSyntax` all branch on the runtime type of a syntax object.
6. **Build.** `MarkdownRenderer.build(DocModel, style)` in
   `features/reader/rendering/` — the only site in the codebase that imports a
   renderer package.

### Why the block index exists

`markdown`'s `Element` carries no source position: it exposes
`tag / attributes / children / textContent / generatedId / footnoteLabel` and
nothing about where in the file it came from. But doc 08 needs every search hit
to map to a block so the reader can scroll to it, and `#anchor` links need the
same mapping. So the pipeline builds that index itself, while it has the source
in hand. It is ours, so it stays correct regardless of which renderer S1 picks.

### What the block index indexes

**Every line and offset in `SourceBlock` indexes `DocModel.sanitizedSource`** —
front matter already lifted out, block HTML already rewritten — because that is
the exact string the renderer parses. Any other coordinate space could not line
up with the widgets the reader scrolls to. `DocModel.rawSource` keeps the file
as decoded, for copying and for anything that needs the original text.

Properties callers may rely on:

- **One block per top-level AST node, in render order**, so `blocks[i]` is the
  renderer's `children[2i]` (doc 01).
- **The blocks partition the source.** Consecutive blocks meet exactly and the
  last runs to the end, so every offset lands in exactly one block. Blank lines
  and link-reference definitions — which produce no node — belong to the block
  above them.
- **Offsets are non-decreasing**, so an offset can be found by binary search.
- **There may be no blocks at all.** An empty file has none, and neither does
  one holding only blank lines or only link-reference definitions; the renderer
  builds nothing for those either. "At least one block" is not an invariant.

Two positions are special, and both are asserted by tests:

- A **setext heading** starts on its text line, not on its `===` underline —
  the parser only reaches that syntax once it is sitting on the underline.
- The **footnote section** the parser synthesizes at the end of a document with
  footnotes has no source of its own: it is built after parsing, out of
  definitions lifted from wherever they were written. It is given an empty
  range at the end of the source, so no offset resolves to it and the
  definitions' own lines stay with the block they were written under.

### Why the source is parsed more than once

`core/markdown/` parses for the outline, slugs and block index; the renderer
package parses `sanitizedSource` again for the widgets. A document containing
block HTML is parsed once more, because the rewrite has to find the regions
before the index can be built over the result.

S1 measured our own pass at 6–7 ms on a 1 MB document against 771–925 ms for
the renderer's — under 1% of the work — so the extra passes are affordable
against the 150 ms first-paint budget (doc 00). What they buy is that the
renderer is handed a string and a model, never our internal AST, which is
precisely what keeps the S1 decision reversible. Do not collapse them without
re-reading this.

## Flavor target: GitHub Flavored Markdown

| Feature | v1 behavior |
|---|---|
| Headings, emphasis, lists, blockquote, hr | Rendered |
| Fenced code + language | Rendered, highlighted (flutter_highlight), copy button, language label |
| Tables | Rendered; wide tables scroll horizontally |
| Task lists | Rendered (checkboxes inert — read-only) |
| Strikethrough, autolinks | Rendered |
| Images | Rendered per policy below |
| Footnotes | Renderer-dependent — recorded as an S1 checklist item |
| Inline/block HTML | **Not rendered** — see HTML policy |
| Emoji shortcodes `:tada:` | Nice-to-have; Unicode emoji always work |
| Math / mermaid | Shown as code blocks (charter non-goal) |

## HTML policy

MarkLens has no HTML engine, deliberately (rules 2, 10).

- **Inline HTML** (`<br>`, `<kbd>x</kbd>`…): shown as escaped literal text in
  a subtle "raw" style.
- **Block HTML**: collapsed box titled "Raw HTML (not rendered)" containing
  the escaped source, expandable.

No exceptions, no tag allowlist creep.

**Implementation note (S1).** `flutter_markdown_plus` emits *nothing at all*
for block HTML — the content disappears rather than being escaped, which is
worse than either rendering or escaping it, because the reader gets no sign
anything was there. The mechanism: `HtmlBlockSyntax` returns a bare `md.Text`
node, and the builder's `visitText` opens with
`if (_blocks.last.tag == null) return;`. See
`docs/spike-results/S1-renderer-bakeoff.md`.

The collapsed box therefore cannot be built by styling the renderer's output.
`RawBlockRewriter` in `core/markdown/` rewrites every top-level HTML region
into a fenced code block first, with the info string `html marklens-raw`: the
first word keeps the body highlighting as HTML, and the rest arrives as
`pre.attributes['data-metadata']`, so the reader can tell a rescued block from
a code fence the author wrote. The fence is one backtick longer than the
longest run inside the region, so nothing in the HTML can close it early.

That rewrite is **not only cosmetic**. A root-level text node is one block to
the index and zero children to the renderer, so `blocks[i] -> children[2i]` is
already wrong for any document containing block HTML. Rewriting restores the
one-to-one mapping, which is why it ships with the index rather than with the
reader.

The regions are located by the parser rather than by a scanner of our own: the
set of top-level `md.Text` nodes *is* the set of block-HTML regions. That brings
CommonMark's seven start conditions, the rule that a blank line closes a type-6
block, unterminated blocks running to end of file, and the fact that a tag not
at the start of its line is inline HTML and must be left alone.

Two accepted gaps:

- **HTML nested inside a list item or block quote still disappears.** It does
  not break the block arithmetic — the enclosing top-level block still produces
  exactly one child — and reaching it would need nested line ranges the
  recorder deliberately does not collect.
- A document that literally contains a fence labelled `html marklens-raw` gets
  the raw-HTML styling. Recorded rather than defended against.

**MDX and this rewriter, since M3.** A block-level `<Component>` alone on a
line is an HTML block by start condition 7 — the tag-name pattern is
`[a-zA-Z][a-zA-Z0-9-]*`, which capitalized names match — so the renderer used
to delete it exactly like a `<div>`, and between M1 and M3 it was rescued here
with no MDX-specific rule. **`MdxSanitizer` now owns it.** It runs first, so by
the time this rewriter sees an `.mdx` document every capitalized or dotted
block tag is already a fence, and what is left is genuine lowercase HTML. The
rescue path is unchanged for `.md`, where it is still the only thing standing
between block HTML and deletion.

A *dotted* tag such as `<Foo.Bar />` was never an HTML block at all, since `.`
is not legal in an HTML tag name, so it was never rescued here. The sanitizer
picks it up by the component heuristic below.

## MDX placeholder spec (render, not run)

Goal: an `.mdx` file is *readable*, its structure visible, and nothing ever
executes. The sanitizer is a **tolerant scanner, not a JSX parser** — it must
be simple enough to reason about and impossible to crash.

Transforms, in order:

1. **ESM lines.** Top-level `import …` / `export …` statements are removed
   from the flow; the document header shows a chip: `MDX · 3 imports hidden`.
2. **Block-level JSX.** A line-starting `<Component …>` (capitalized tag or
   dotted like `<Foo.Bar>`), spanning to its balanced close (or self-closing
   `/>`), becomes a **placeholder card**: component name, a one-line summary
   of its attributes, and an expandable escaped raw-source section. Children
   that are plain markdown are rendered *inside* the card when trivially
   extractable; otherwise the raw source expansion carries them.
3. **Inline JSX** inside a paragraph → inline chip `⟨Component⟩`, written as
   an inline code span. A closing tag keeps its slash (`⟨/Component⟩`) so an
   open/close pair still reads as a pair.
4. **Braced expressions** `{expr}` in text → inline-code style, literal.
5. **Ambiguity bail-out.** Unbalanced tags, nesting deeper than 20, or any
   construct the scanner can't classify within its rules → that region is
   emitted as a fenced code block labelled `mdx`. Bailing out is correct
   behavior, not an error.

Heuristics locked: a "component tag" starts with `[A-Z]` or contains a dot;
lowercase tags (`<div>`) are HTML and follow the HTML policy instead. The
scanner operates outside fenced code blocks and inline code only.

Test corpus: `test/fixtures/torture/mdx/` includes adversarial cases —
unterminated tags, JSX inside blockquotes, code fences containing fake JSX,
10,000 sibling components, `{}` inside links.

### What building it settled — M3

**It is a source-to-source rewrite**, like `RawBlockRewriter` and for the same
reason: `core/markdown/` is pure Dart and ends at a string (doc 02's seam), so
every transform above has to be expressible as inert Markdown. Four of them are
fences or code spans, and the placeholder card rides the same
`data-metadata` rail the raw-HTML box does — `` ```jsx marklens-mdx Callout type
title ``. The fifth, the count of hidden ESM statements, is a count of text that
is no longer there, so it travels beside the string as `DocModel.mdxImportsHidden`
rather than inside it.

Seven things the spec above did not settle, decided while building it:

- **The card does not re-render its children.** Transform 2 used to say plain
  markdown children are rendered *inside* the card "when trivially
  extractable". They are not, and the raw-source expansion carries them
  instead. Rendering them would mean a second `MarkdownWidget` nested inside a
  block, which nests a scroll view and a selection scope inside the one the
  reader owns — and a nested selection scope ending a drag at the top of a
  block is precisely what S2 made a release gate
  (`docs/spike-results/S2-selection.md`).
- **The attribute summary is attribute *names*.** The summary rides the
  fence's info string, which is one line and, for a backtick fence, may not
  contain a backtick — and an attribute *value* can hold both. Names are
  identifiers, so they are safe there; the body still carries the whole tag.
  Capped at eight, because a card header is not a place to read forty of them.
- **Block-level means the region is the whole line.** `<Foo /> and then prose`
  is a paragraph containing a component, and gets the chip. Only a region that
  ends its line becomes a card.
- **A bail-out covers the opening tag, not the rest of the file.** For an
  unclosed `<Callout>`, the fence holds that tag alone and the heading and
  prose below it survive — the fixture asks for exactly this, "rather than
  guessing where it ends". A region that *does* close but nests too deep is
  fenced whole, since its bounds are known.
- **An unbalanced brace is not an expression.** `{unclosed` is left as the
  literal text it already renders as. Transform 5 is for regions; emitting a
  fenced block over a stray character would destroy the paragraph around it.
- **Indented code is skipped too**, not only fenced and inline code. Four
  spaces after a blank line is code by CommonMark and the corpus expects it
  untouched. The approximation is the "after a blank line" part, which is what
  keeps this a line scanner: a lazily indented paragraph continuation reads as
  code and is left alone, which is the safe direction.
- **A tag may wrap lines but not span a blank one.** Without it, an
  unterminated `<Another attr="value"` scans forward to whatever `>` appears
  next and swallows everything between.
- **The searches for a closing tag share one budget for the whole document**,
  four times its length plus a floor — and CI is what proved a per-region cap
  was not enough. The 64 KB span limit only engages on a document *larger* than
  64 KB, so a 60 KB file of ten thousand unclosed components still scanned to
  the end ten thousand times: 117 ms, 396 ms and 1557 ms for 2,500, 5,000 and
  10,000 of them, four times the work for twice the input. One shared budget
  makes it linear — the same figures become 12 ms, 7 ms and 5 ms — and changes
  nothing about the output, because a region that runs out of budget gives up
  looking for a close earlier, which is the fenced `mdx` block transform 5
  already prescribes. Five seconds to open a 60 KB file is a denial of service
  in the only sense that matters here (rule 9, doc 00 principle 3).

Two accepted gaps, recorded rather than defended against:

- A lowercase *dotted* tag is a component by the locked heuristic, so a
  hypothetical `<example.com>` would be read as one. Real autolinks are not
  affected: a tag name must be followed by whitespace, `/` or `>`, and
  `<https://example.com>` and `<a@b.example>` both fail that.
- The ESM count includes `export` statements, because they are what the
  transform removes; the chip's wording ("imports hidden") is the shorthand
  doc 04 has always used for them. `esm_imports.mdx` was corrected from 3 to 4
  when the multi-line `export default` at its foot turned out to be a
  statement like any other.

## Images

- **Local only by default.** `src` resolves relative to the document's
  directory; absolute local paths allowed. Extension allowlist: png, jpg,
  jpeg, gif, webp, bmp, svg (via flutter_svg). Anything else → placeholder.
- **Size guard:** files > 25 MB show a placeholder with a "load anyway"
  affordance (still local, still user-initiated).
- **Remote `http(s)` images:** blocked placeholder showing the URL and a
  hint to the setting (`network.allowRemoteImages`, default **off**). No
  per-image "allow once" in v1 — the zero-network default stays legible.
- Broken path → placeholder with the resolved path (aids debugging docs).

### What building it settled — M3

- **A `src` with no scheme is not automatically local.** Two shapes reach the
  local branch and must not: a **protocol-relative URL**
  (`//example.com/tracker.png`), which has no scheme so it falls through every
  scheme check ever written; and a **UNC path** (`\server\share\x.png`), which
  `Uri` does not parse at all. Either one handed to `File.statSync` is Windows
  opening an SMB connection to a host the *document* chose — invariant 4 by a
  side door. Both are refused. The corpus carries one of each; that is how this
  was found, and neither the classifier nor this document had a rule for it
  before.
- **`data:` is refused with every other scheme.** An inline payload is a
  decoder pointed at document content, which is the shape invariant 3 refuses;
  the size cap and the extension allowlist both mean nothing against it.
- **Classification is pure; existence and size are not.** `core/images/` reads
  no disk at all — `imageBuilder` is called on every rebuild and a `ListView`
  rebuilds as it scrolls, so a `statSync` per image per frame is the sort of
  thing that is invisible in a test and audible in a 1 MB document. The widget
  stats once, in `initState`.
- **A query string is dropped before the extension is read**, or `logo.png?v=2`
  is a file of type `png?v=2`.
- **One placeholder shape, five reasons.** Blocked, missing, oversize,
  unsupported and undecodable are one thing to a reader — *there was a picture
  here and it is not showing* — so only the words differ, and each set of words
  says which of the five it was. The alt text rides along, because it is the
  only part of the image a reader can still get, and the box carries it as its
  semantics label (`container: true`, or the label merges with the explanation
  and a screen reader reads the box twice).

## Heading anchors

GitHub slug algorithm: lowercase, spaces → `-`, strip punctuation, duplicate
slugs get `-1`, `-2`… Used by the outline, `#anchor` links, and cross-file
`file.md#anchor` links.

**Headings nested inside a block quote or a list item are included** in the
outline, carrying the index of the top-level block that renders them, since
they have no block of their own. Skipping them would be worse than imprecise:
duplicate suffixes are assigned in document order, so leaving one out shifts
the `-1`/`-2` of every later heading with the same text and silently breaks the
anchors of headings that are not nested at all.

Two consequences worth writing down. Heading text comes from the AST's
`textContent`, so image alt text inside a heading does not reach the slug. And
headings inside a footnote definition are visited in render order, after the
rest of the document, because the parser hoists those definitions to the end.

## Large documents

Rendering builds one widget per top-level block, from a **single
whole-document parse**. Never per-block parsing: S1 measured that an isolated
paragraph renders `[the reference][ref]` as literal brackets, because the
definition lives in another block. Both candidate renderers hand back exactly
this block list from one parse, so per-block scroll targets cost nothing.

Note what "block-lazy" does and does not mean here: block *layout* is lazy,
block *widget construction* is eager and O(document) in both renderers. A 1 MB
document produces 13k–26k block widgets before the first frame.

S1 found a three-way conflict between block-laziness, whole-document
`SelectionArea` (doc 06) and 55 fps on 1 MB (doc 00), since a child that has
not been built cannot be selected. **S2 resolved it: laziness and 55 fps win.**

Building every block up front costs 527 ms to first paint on a *typical*
100 KB document — three and a half times the charter budget — and kills the
process at 1 MB. Whole-document selection was replaced by File → Copy entire
document, which reads the `DocModel` rather than the widget tree (doc 06). See
`docs/spike-results/S2-selection.md`.
Documents > 10 MB open with a "large file" banner; > 50 MB are refused with
a friendly dialog (charter: viewer, not log reader). The 1 MB torture file
must hold ≥ 55 fps scrolling (doc 00).
