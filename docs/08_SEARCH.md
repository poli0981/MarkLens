# 08 · Search

Three entry points, one principle: search the *source text*, map hits to
block positions for scrolling.

## Find in file — `Ctrl+F`

Inline bar floating over the reader — over, not above: a bar that reflowed the
page would move the very text you were looking at. Query, case toggle, match
counter `3/17`, Enter / Shift+Enter to cycle with wraparound, Esc closes.
Implementation: literal search over the document source; each hit maps to its
block index → scroll to that block. Matches inside MDX placeholder raw sections
count (they are readable content).

**Highlighting is per block, not per match — amended at M2, measured.** This
section used to ask for every match highlighted in the rendered view. That is
not reachable through `flutter_markdown_plus`, and the three ways round it are
each worse than the feature:

- `MarkdownStyleSheet` maps *tags* to styles. There is no per-run or
  per-offset entry point anywhere in it.
- A `MarkdownElementBuilder` is handed a whole element and the *block's* style,
  not the inline style in force. Re-rendering every `p`, `li`, `td`,
  `blockquote` and heading to inject highlight spans would drop the bold,
  italic, inline code, strikethrough and link styling inside them — a fidelity
  regression far larger than the feature is worth.
- An `inlineSyntax` would work on the parse, but the widget only re-parses when
  its `data` or `styleSheet` changes, so a query change would need a forced
  re-parse of the whole document per keystroke — 70 ms at 100 KB, far worse at
  1 MB, against a 150 ms first-paint budget. Worse, a query containing `*`,
  `_`, `[` or a backtick would be consumed by that syntax and visibly break the
  surrounding emphasis: **typing in the find bar would change how the document
  renders.**

So a block containing a match takes a faint accent tint, and the current match
scrolls into view and takes the stronger accent pulse. The counter, the
cycling, the case toggle and Esc all behave exactly as specified. Character-level
highlighting inside rendered prose is a v1.x candidate, and reaching it means
either a renderer that exposes span-level styling or our own inline builder.

**Which string is searched.** `DocModel.sanitizedSource` — the same string
`SourceBlock` indexes (doc 04), so a hit offset resolves to a block with no
translation step. Front-matter matches therefore do not come from this search:
the front-matter panel is its own surface and searches `FrontMatter.raw`, and a
hit there scrolls the panel rather than the block list. A raw-to-sanitized
offset map is deliberately out of scope; it would have to be rebuilt every time
the MDX sanitizer changed a length, for a payoff of one shared match counter.

## Search open files — `Ctrl+Shift+F`

Panel replacing the sidebar: query + case toggle, results grouped by file
with per-hit context line, click → open/activate tab and jump. Literal in
v1 (regex toggle is a v1.x candidate).

Execution: `Isolate.run` — the isolate receives the open-set path list,
reads files straight from disk (documents don't need to be parsed or cached
to be searched), scans, and returns grouped hits. Budget: 1,000 files ×
~10 KB in **< 300 ms** on the reference machine.

### What building it settled — M3

- **A hit carries a line, not an offset, and a click re-finds it.** The scan
  reads the file *from disk*; `SourceBlock` indexes
  `DocModel.sanitizedSource`, which has the front matter lifted out, block HTML
  rewritten and MDX sanitized. A raw offset handed to `blockIndexOf` would name
  the wrong block, and a raw-to-sanitized map is exactly what this document
  refused for find-in-file. So a result carries its **ordinal within its file**,
  and the click activates the tab and re-runs `findInSource` over the parsed
  document: the *n*th hit there is the *n*th hit here. The two agree exactly
  whenever the two strings are equal, and stay in step when they are not.
- **Cancellation is the caller's.** `Isolate.run` cannot be killed from
  outside, so `CrossSearchController` debounces the query by 150 ms and
  discards the result of a run it no longer wants, by generation counter. That
  buys what cancellation buys — no stale results, no scan per keystroke — at a
  cost of one superseded scan finishing on its own, which against a 300 ms
  budget is cheaper than the machinery to stop it. The line above used to say
  "streams grouped hits back"; it returns them once, because a scan that fits
  the budget has nothing to stream.
- **The per-file cap is 50, and it is reported.** A file whose list was cut
  short shows `50+` rather than `50`. A panel that silently shows fifty of nine
  thousand matches is lying about the document.
- **The panel does not persist.** `session.json` v1 has no field for which
  panel is in the sidebar column, and a window reopening three days later still
  showing a search for "TODO" would be restoring a question nobody is asking.
  `Ctrl+B` puts the column away and brings back the file list.

## Quick switcher — `Ctrl+P`

Fuzzy match over open-set names + relative paths + recent list. Subsequence
scoring (word-boundary and path-segment bonuses), top 20, arrows + Enter.
This is the intended navigation for a 1,000-entry session — the tab strip is
for the working few, Ctrl+P is for everything.

## Non-goals

No persistent index, no content search of *unopened* folders, no
search-and-replace (read-only, forever).
