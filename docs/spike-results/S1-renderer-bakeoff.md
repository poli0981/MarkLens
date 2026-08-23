# S1 — Renderer bake-off

**Status:** measurable criteria closed — both candidates pass; the pin waits on S2
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
| `integration_test/s1_scroll_perf_test.dart` + `test_driver/perf_driver.dart` | The real thing: profile-mode scroll gate, writes `build/s1_scroll_gate.md` |

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

## Result 6 — the scroll gate: both pass, comfortably

Profile mode, Windows 11, 1 MB document, scrolling 160,000 px sampled at four
depths (0%, 25%, 50%, 75% of the scroll extent) so the measurement is not just
the top of the file. Gate: 18.18 ms/frame.

| | A | B |
|---|--:|--:|
| avg frame build | 1.45 ms | 1.25 ms |
| avg frame raster | 1.13 ms | 0.98 ms |
| p90 build | 1.89 ms | 1.74 ms |
| p99 build | 2.38 ms | 2.37 ms |
| missed build budget | **0** | **0** |
| missed raster budget | **0** | **0** |
| verdict | **PASS** | **PASS** |

Even the 99th-percentile frame is roughly eight times inside budget. The
"687 fps / 800 fps" the driver prints is `1000 / worst-average-phase`, not a
real frame rate — what it means is that per-frame work while scrolling is
around 1.5 ms, with the rest of the budget unused.

**First paint, typical 100 KB document: 70 ms against a 150 ms budget — PASS**
(`docs/00_CHARTER.md`).

First paint on the 1 MB document is 508 ms (A) / 587 ms (B). No charter
criterion covers it, and it is the number worth watching: the eager widget
construction from Result 4 shows up here, not in scrolling.

### What it took to make this measurement trustworthy

Recorded because every one of these produced a confident, wrong number first:

1. **`tester.fling` scrolled the list by zero pixels** — and the run still
   reported "PASS (1078.3 fps)", measured entirely on a stationary list.
   Scrolling is now driven through the `ScrollController`, and the test
   asserts on pixels actually travelled.
2. **`pumpAndSettle()` defaults to 100 ms steps**, coarse enough that a
   two-second animation leaves about twenty frames in the trace.
3. **`traceAction` defaults to every timeline stream**, which fills the VM's
   ring buffer with GC and compiler noise; the summary saw 21 of 1356 rendered
   frames. Restricted to `Dart` and `Embedder` — and the names are the VM
   service's, so lowercase is rejected outright.
4. **The timeline buffer is sized in bytes, not seconds.** Lengthening the
   trace does not capture more frames, it just moves the window: 12-segment and
   24-segment runs both captured 253 frames. The driver now reports
   `captured_span_ms` (4.2 s of a ~20 s run) so this is visible rather than
   mysterious.

The harness is only worth having because it now fails loudly instead of
passing quietly.

## Still open

1. **Styling hooks against the doc 06 theme tokens.** A exposes
   `MarkdownStyleSheet`, B exposes `MarkdownConfig` with per-element configs;
   both look sufficient on inspection, but neither has been driven from the
   real token set — which does not exist yet, because doc 06 defers it to M1.
   This S1 criterion cannot fully close before then.
2. **The highlighter decision** (`flutter_highlight` vs `re_highlight` vs
   `syntax_highlight`) — not started.
3. **S2 selection quality**, which Q3 above has already complicated.

## Recommendation: candidate A, for the maintainer to ratify

Performance is **not** a tiebreaker. Both candidates clear the scroll gate by
roughly an order of magnitude, both hit zero missed frames, and B's advantage
(1.25 ms vs 1.45 ms average build) is invisible to a reader. A difference that
large a margin inside budget should not decide a dependency that has to last
years.

What is left is maintenance, and there the gap is structural rather than
marginal:

- **A**: BSD-3, verified publisher, released six weeks ago, three pure-Dart
  dependencies.
- **B**: MIT, verified publisher, but sixteen months without a release, and it
  pulls `flutter_highlight ^0.7.0` as a **hard** dependency — the same
  five-year-old package doc 01 flags as our most fragile pin, except through B
  we would not control the choice at all. Plus `url_launcher`,
  `visibility_detector` and `scroll_to_index`, each another thing to audit.

A's two real costs are both bounded and have known mitigations:

| Cost | Mitigation |
|---|---|
| Spacer-interleaved block list (`children[2i]`) | Index arithmetic, covered by a regression test that fails if the spacing behaviour changes |
| Silently drops block HTML | Rewrite block HTML into a fenced code block in `core/markdown/` before the renderer sees it — which doc 04 now specifies, and which we would want under B too, since our HTML box is our own design either way |

**The pin in `docs/01_TECH_STACK.md` still should not move yet.** Doc 15 makes
S2 a "fail here = revisit S1 choice" gate, and Q3 above has already shown that
selection over a lazy list does not work as specified. Ratify A after S2
settles what selection actually looks like — not before.
