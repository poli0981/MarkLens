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

**MDX, before the sanitizer exists.** A block-level `<Component>` alone on a
line is an HTML block by start condition 7 — the tag-name pattern is
`[a-zA-Z][a-zA-Z0-9-]*`, which capitalized names match — so the renderer used
to delete it exactly like a `<div>`. It is now rescued by the same code path,
with no MDX-specific rule. A *dotted* tag such as `<Foo.Bar />` is not an HTML
block at all, since `.` is not legal in an HTML tag name; it stays a paragraph
and already renders as literal text, so it is left alone until the sanitizer
lands in M3.

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
3. **Inline JSX** inside a paragraph → inline chip `⟨Component⟩`.
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
