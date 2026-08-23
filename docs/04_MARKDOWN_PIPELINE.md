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
        → [mdx sanitize] → parse → DocModel  ────┼──→ MarkdownRenderer.build
                    (outline · slugs · blocks)   │          → widgets
```

1. **Decode.** UTF-8, BOM stripped. Invalid sequences decode lossily
   (U+FFFD) and raise a non-blocking notice bar.
2. **Front-matter.** A leading `---` fenced block is lifted out before
   parsing and shown as a collapsible key/value panel (setting: collapsed /
   expanded / hidden). YAML that fails to parse as simple `key: value` lines
   is shown raw inside the panel — never fed to the renderer, never fatal.
3. **MDX sanitize** (`.mdx` only — by extension, no sniffing). See below.
4. **Parse.** Through the pure-Dart `markdown` package (Dart team). One pass
   yields the AST, the heading **outline** with its slugs, and the **block
   index** — the source line range of every top-level block.
5. **Build.** `MarkdownRenderer.build(DocModel, style)` in
   `features/reader/rendering/` — the only site in the codebase that imports a
   renderer package.

### Why the block index exists

`markdown`'s `Element` carries no source position: it exposes
`tag / attributes / children / textContent / generatedId / footnoteLabel` and
nothing about where in the file it came from. But doc 08 needs every search hit
to map to a block so the reader can scroll to it, and `#anchor` links need the
same mapping. So the pipeline builds that index itself, fence-aware, while it
has the source in hand. It is ours, so it stays correct regardless of which
renderer S1 picks.

### Why the source is parsed twice

`core/markdown/` parses for the outline, slugs and block index; the renderer
package parses `sanitizedSource` again for the widgets. On a 100 KB document
that is a few milliseconds against the 150 ms first-paint budget (doc 00), and
it is precisely what keeps the S1 decision reversible — the renderer is handed
a string and a model, never our internal AST. Do not collapse the two passes
without re-reading this.

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
anything was there. The collapsed box therefore cannot be built by styling the
renderer's output; block HTML has to be rewritten into a fenced code block in
`core/markdown/` before the renderer ever sees it. See
`docs/spike-results/S1-renderer-bakeoff.md`.

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
