# S2 — Selection & copy quality

**Status:** complete — quality gate passes; `docs/06_UI_UX.md` amended
**Branch:** `spike/s2-selection`
**Machine:** Windows 11, Flutter 3.47.1 / Dart 3.13.1
**Date:** 2026-08-23

Doc 15's gate: selecting across a heading, a paragraph, a code block and a
table cell must yield clean clipboard text; Vietnamese diacritics and Japanese
must survive; code-block formatting must be preserved. **Fail here = revisit
the S1 choice.**

## How this was measured

`test/spike/s2_selection_probe_test.dart` drives real selection: a mouse
gesture to focus the region, `Ctrl+A`, `Ctrl+C`, and a mocked
`SystemChannels.platform` to capture what actually reached the clipboard.

Every assertion checks the clipboard is **non-empty before** inspecting it.
The S1 perf harness once reported a confident "1078 fps" measured on a list
that never scrolled; a selection probe that silently selects nothing fails the
same way, and this one is built so it cannot.

`integration_test/s2_eager_layout_test.dart` prices the layout that
whole-document selection would require, in profile mode.

## Result 1 — the quality gate passes

Selecting across the full mixed document copies cleanly:

| Checked | Outcome |
|---|---|
| heading → paragraph → code block → table cell → final paragraph | all present |
| Vietnamese diacritics (`Chương một`, `ô một`) | preserved, not stripped to ASCII |
| Japanese paragraph | preserved |
| code block newlines **and indentation** (`  print('hello');`) | preserved exactly |

And it passes on **both** layouts, so selection quality is a property of
candidate A rather than of how we arrange its blocks. **S2 does not fail, so
the S1 choice stands.**

## Result 2 — native `selectable: true` is not an alternative

Candidate A's own selection mode emits a `SelectableText` island **per block**
and no `SelectableRegion` at all. Select-all inside one stops at that block's
boundary. `SelectionArea` wrapping our block list is the only route to
cross-block selection.

## Result 3 — whole-document selection cannot be afforded

`docs/06_UI_UX.md` wanted the whole document inside one `SelectionArea`, which
requires every block to be built. Profile-mode ladder:

| Document | Lazy first paint | Eager first paint |
|---|--:|--:|
| 100 KB | 72 ms | **527 ms** |
| 200 KB | 112 ms | 1,142 ms |
| 400 KB | 214 ms | 2,338 ms |
| 700 KB | 333 ms | 4,439 ms |
| 1 MB | 487 ms | **process died** |

Eager layout blows the charter's 150 ms first-paint budget at the *typical*
100 KB document — three and a half times over — and at 1 MB it takes the app
with it. There is no threshold worth having: even a 25 KB document would sit
at the budget line.

The 1 MB data point exists only because the ladder appends each result to disk
before attempting the next size. The first attempt at this measurement lost the
entire run when the VM service disappeared mid-test.

## Result 4 — the loss is much smaller than it looks

Dragging past the viewport edge auto-scrolls, and the selection **extends into
blocks built during the drag**: 50 contiguous paragraphs selected where only
22 were built when the mouse went down, with no gaps.

So laziness costs exactly one thing — selecting the entire document *without
dragging through it*. Ordinary passage selection, however long, is unaffected.

## Resolution

Laziness stays. `docs/06_UI_UX.md` is amended:

- **Drag selection** works over the rendered view, auto-scrolling and
  extending as blocks build. This is the release gate, and it passes.
- **File → Copy entire document (`Ctrl+Shift+C`)** replaces "select the whole
  document and copy". It reads `DocModel.sanitizedSource` directly, so it is
  exact by construction and does not care what has been built. `Ctrl+A` keeps
  its conventional meaning: select what is rendered.
- What it copies is the **Markdown source**, not a rendered plain-text
  serialisation. It is exact, needs no serialiser of its own, and for a
  Markdown viewer the source is usually what someone wants to paste elsewhere.
  The difference from drag-selected text is deliberate and documented.

The three-way conflict S1 found is therefore resolved as: **block-laziness and
55 fps win; whole-document `SelectionArea` loses and is replaced.**

## Consequence for S1

S2 passed, and the whole-document limitation is a Flutter property rather than
a renderer property — candidate B would hit it identically, since both build a
block list and both would need it eagerly laid out.

**Candidate A is ratified.** `flutter_markdown_plus 1.0.12` is now the pin in
`docs/01_TECH_STACK.md`; `markdown_widget` drops out of the candidate table
and out of `legal/THIRD_PARTY_NOTICES.md`, since it is no longer shipped.

## Still open

- The highlighter decision (`flutter_highlight` vs `re_highlight` vs
  `syntax_highlight`) — still not started; it is now the last open piece of S1.
- The doc 06 styling-token check, blocked until M1 defines the tokens.
