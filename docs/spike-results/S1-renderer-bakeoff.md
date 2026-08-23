# S1 — Renderer bake-off

**Status:** partial — structural questions answered, release gates still open
**Branch:** `spike/s1-renderer-bakeoff`
**Machine:** Windows 11, Flutter 3.47.1 / Dart 3.13.1
**Date:** 2026-08-23

Candidates per `docs/01_TECH_STACK.md`: **A** = `flutter_markdown_plus 1.0.12`,
**B** = `markdown_widget 2.3.2+8`.

## How this was measured

Three probes on the torture corpus, all committed on the spike branch:

| Probe | What it does |
|---|---|
| `test/spike/s1_fidelity_probe_test.dart` | Renders all 23 corpus pages through both candidates, censuses the widget tree, writes `build/s1_fidelity_probe.md` |
| `test/spike/s1_structure_probe_test.dart` | Answers the three structural questions with assertions |
| `test/spike/s1_perf_probe_test.dart` | Times parse and first paint on 1 MB and 100 KB, writes `build/s1_perf_probe.md` |

Both candidates were implemented against the real `MarkdownRenderer` interface
(`lib/features/reader/rendering/`). **That is itself a result:** the seam from
`docs/02_ARCHITECTURE.md` fits both without contortion, so the M0 decision to
move it out of `core/` holds up against a second implementation.

## Result 1 — neither candidate crashes

46 renders (23 fixtures × 2 candidates), zero exceptions — including malformed
UTF-8, unterminated fences, unterminated JSX, 25-deep component nesting, ragged
tables and pathological list nesting. CLAUDE.md rule 9 is satisfied by both at
the renderer layer.

## Result 2 — both render the GFM matrix, and agree on tables

`gfm/04_tables.md` produces **7 `Table` widgets from both**, matching the seven
tables in the fixture, alignment and ragged rows included.

Task-list checkboxes render as `Icon(Icons.check_box)` in **both**, not as a
`Checkbox` widget. That is better than the spec asked for: an `Icon` is
inherently inert, which is exactly the read-only behaviour `docs/04` wants, and
both expose a checkbox builder if we want our own.

## Result 3 — candidate A silently drops block HTML

`# H` / `<div>block html</div>` / `# H2` produces **two** blocks from A. The
`<div>` yields no widget at all and its text never reaches the tree. An HTML
comment behaves the same way.

`docs/04_MARKDOWN_PIPELINE.md` requires block HTML to collapse into a
"Raw HTML (not rendered)" box holding the escaped source. A does not merely
fail to render it — it **deletes it**, which is worse than either rendering or
escaping, because the reader gets no sign that content was there.

**Consequence:** whichever candidate wins, the HTML policy has to be
implemented upstream of it — most likely as a pre-pass in `core/markdown/` that
rewrites block HTML into a fenced code block before the renderer sees it. That
is now a known M2 work item, not an assumption.

## Result 4 — the three structural questions

### Q1. Does the block list map onto source blocks?

**A: no, not directly. B: yes.**

`_addBlockChild` in A inserts a `SizedBox(height: blockSpacing)` between every
pair of blocks, so its child list is `2N-1` entries for `N` real blocks —
verified: five source blocks produce nine entries, with a spacer at every odd
index. B's `MarkdownGenerator.buildWidgets` returns exactly `N`.

Filtering the spacers out by type is **not** safe: an empty heading (`#`) is a
real block that A also renders as `const SizedBox()`. Index arithmetic
(`sourceBlock[i] → children[2i]`) is the only correct mapping, and it depends
on an implementation detail of A that no test of theirs protects.

Across the corpus, A's count is exactly `2B-1` on every pure-Markdown fixture
and diverges only on the HTML and MDX ones — which is Result 3 showing up in
the arithmetic.

### Q2. One widget per document, or one widget per block?

**Settled, and not a discriminator.** Both candidates hand back a `List<Widget>`
of top-level blocks from a *single whole-document parse* — A via
`MarkdownWidget.build(context, children)`, B via
`MarkdownGenerator.buildWidgets`. So we get per-block widgets to scroll to
without per-block parsing.

That distinction is load-bearing. Measured: parsing the whole document resolves
`[the reference][ref]`, while parsing that paragraph in isolation renders the
literal brackets. Per-block *parsing* would break reference links and
footnotes; per-block *widgets from one parse* does not.

The doc 04 phrasing "the renderer builds a lazy list of block widgets" is
inaccurate for both: block *widget construction* is eager and O(document);
only element and render-object creation is lazy. Doc 04 should be corrected.

### Q3. Can `SelectionArea` coexist with a lazy list?

**No. The conflict is real, and confirmed.**

With a 200-paragraph document in an 800×600 viewport, fewer than 200 `RichText`
widgets are built and the last paragraph is absent from the tree entirely. A
`SelectionArea` wrapping the list has nothing to select there, so
"select the whole document and copy" — a release gate under S2 — cannot work
over a lazily built list.

The three requirements (`docs/06` whole-document selection, `docs/04`
block-laziness, `docs/00` 55 fps on 1 MB) do not hold together as written. One
of them has to give, and the choice belongs in S2 with the doc amended to match.

## Result 5 — cost (debug mode)

Flutter debug builds run with assertions on, so these are upper bounds several
times worse than release. The ratios, measured under identical conditions, are
the usable signal.

| Input | Measurement | A | B |
|---|---|--:|--:|
| 1 MB (1,099,308 bytes) | `pipeline.parse` (ours, pure Dart) | 6–7 ms | 6–7 ms |
| | block widgets produced | 26,259 | 13,130 |
| | first paint | 925 ms | 771 ms |
| 100 KB | `pipeline.parse` | 2 ms | — |
| | block widgets produced | 2,667 | — |
| | first paint | 99 ms | — |

Two things worth keeping:

- **The double parse is not a cost worth worrying about.** Our pure-Dart pass
  over 1 MB takes 6–7 ms against a renderer cost of 771–925 ms — under 1% of
  the work. The doc 02 decision to keep `core/` pure is cheap in practice.
- **100 KB debug first paint is 99 ms** against a 150 ms *release* budget
  (`docs/00`). Comfortable, but the 1 MB case is nearly a second even before
  scrolling starts, which is what makes Q3's laziness question load-bearing
  rather than academic.

## Still open

1. **The ≥ 55 fps scroll gate.** Not measurable in widget tests — they drive a
   fake clock, so there are no real frames to time. Needs a profile-mode run
   (`flutter drive --profile`) on the reference machine.
2. **Styling hooks against the doc 06 theme tokens.** A exposes
   `MarkdownStyleSheet`, B exposes `MarkdownConfig` with per-element configs;
   both look sufficient on inspection, but neither has been driven from the
   real token set, which does not exist yet.
3. **The highlighter decision** (`flutter_highlight` vs `re_highlight` vs
   `syntax_highlight`) — not started.
4. **S2 selection quality**, which Q3 above has already complicated.

## Reading so far — not yet a verdict

On the measurements taken, **B is ahead on structure and cost** (1:1 block
list, half the widgets, ~17% faster first paint) and **A is ahead on
maintenance** (six-week-old release from a verified publisher, versus sixteen
months and four extra transitive packages, one of which is the five-year-old
`flutter_highlight` as a *hard* dependency rather than a choice we control).

Doc 01 called A the default favourite on pedigree. The measurements do not
contradict that, but they do make it a closer call than the table implied, and
A's silent HTML deletion plus its spacer-interleaved block list are concrete
costs that were not visible before this spike.

**No pin is being changed in `docs/01_TECH_STACK.md` yet.** The fps gate is the
one criterion doc 15 makes non-negotiable, and it is exactly the criterion still
unmeasured.
