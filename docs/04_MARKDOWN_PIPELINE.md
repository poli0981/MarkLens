# 04 · Markdown pipeline

The pipeline is the product. Every stage is defensive (rule 9) and every
stage is pure Dart (rule 3).

## Stages

```
bytes → decode → front-matter split → [mdx sanitize] → parse → widgets+outline
```

1. **Decode.** UTF-8, BOM stripped. Invalid sequences decode lossily
   (U+FFFD) and raise a non-blocking notice bar.
2. **Front-matter.** A leading `---` fenced block is lifted out before
   parsing and shown as a collapsible key/value panel (setting: collapsed /
   expanded / hidden). YAML that fails to parse as simple `key: value` lines
   is shown raw inside the panel — never fed to the renderer, never fatal.
3. **MDX sanitize** (`.mdx` only — by extension, no sniffing). See below.
4. **Parse + build.** Through `MarkdownRenderer` (S1 winner). Outline is
   extracted from the heading nodes in the same pass.

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

Rendering is block-lazy (the renderer builds a lazy list of block widgets).
Documents > 10 MB open with a "large file" banner; > 50 MB are refused with
a friendly dialog (charter: viewer, not log reader). The 1 MB torture file
must hold ≥ 55 fps scrolling (doc 00).
