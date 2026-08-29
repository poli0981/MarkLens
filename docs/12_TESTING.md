# 12 · Testing

## Pyramid

1. **Core unit tests** (pure Dart, fast, the bulk):
   - MarkdownPipeline: front-matter cases (valid, invalid YAML, `---` in
     body, CRLF), decode (BOM, invalid UTF-8), heading-slug algorithm
     (dedupe, punctuation, Vietnamese diacritics, Japanese).
   - **MdxSanitizer golden corpus**: every transform rule and every
     adversarial fixture in `test/fixtures/torture/mdx/` has an expected
     placeholder-model output. Bail-out cases assert the code-block
     fallback, never an exception.
   - SessionStore/SettingsStore: schema round-trip, atomic-write behavior,
     corruption recovery, each migration with a fixture pair.
   - FileService: natural sort, symlink-dir skip, cap dialog data, dedupe.
   - DocCache LRU; WatchService event normalization (synthetic
     delete+create / rename sequences → `changed`).
   - SearchService: hit mapping, cancellation, isolate round-trip.
2. **Widget tests**: sidebar virtualization + badges, tab MRU cycling,
   find bar counter/cycling, quick-switcher scoring, front-matter panel
   states, placeholder cards, menu keyboard navigation, and **selection
   quality** (`test/features/reader_selection_test.dart`) — cross-block copy,
   Vietnamese and Japanese, code indentation, and auto-scroll drag. That last
   group is a release gate (doc 15, S2).
3. **Golden tests.** Two kinds, and the distinction matters because only one
   of them exists yet.

   **Layout goldens** — `test/goldens/shell_chrome_golden_test.dart`, the first
   goldens in the repo, added at M2. They pin the chrome the first visual pass
   found broken: where the menu bar starts and how wide it runs, and which
   fields the status bar shows in what order. They depend on no font, because
   `flutter_test` substitutes its own fixed-width test font, and on no
   filesystem — every fixture is a literal, since a golden that embeds
   `Directory.systemTemp` differs between the dev machine and the runner.

   **Renderer goldens** — torture pages, the ones this section was originally
   about. **Still unwritten**, and blocked: they need the bundled fonts, and
   `pubspec.yaml` has no `fonts:` entry despite doc 01 describing three. Doc
   01's open Noto Sans JP size decision has to close first.

   **Both run on the ubuntu CI runner only**, and must be **generated** there
   too. For renderer goldens the reason is the bundled fonts; for the layout
   goldens it is rasterization, which differs between platforms whatever the
   font. That is measured, not assumed: the first goldens were generated on the
   Windows dev machine and **four of the five differed from the Ubuntu render
   byte-for-byte**, so they would have failed the CI job on its first
   activation. Nothing about the layout was wrong on either platform.

   `tool/goldens/` holds an `ubuntu:24.04` container with the doc 01 Flutter
   pin, and the two commands — one to rewrite the references, one to check them
   the way CI does. Use it; do not regenerate on Windows.

   **The CI job pins `ubuntu-24.04` to match that container**, and the match is
   the whole point rather than a detail. `ubuntu-latest` is 24.04 today and
   26.04 images already exist; a label that moves would fail every golden
   simultaneously, byte-for-byte, with every layout still correct — which is
   the same failure the Windows-versus-Ubuntu generation produced, and it reads
   like a flake both times. `test/repo/pin_agreement_test.dart` asserts the
   job's image and the Dockerfile's `FROM` tag are the same number.

   **`test/goldens/goldens/` is source; `test/goldens/failures/` is not.**
   `flutter_test` dumps four PNGs per failing golden into the second — master,
   test render, and two diffs — and twelve of them were committed at M2 and
   survived two milestones, because a binary file nobody opens is invisible in
   review. `failures/` is gitignored, and the `analyze` job fails if anything
   under it is tracked.

   Mechanics: the tag is declared in `dart_test.yaml`,
   each golden file starts with `@Tags(['golden'])` — the CI job self-activates
   by grepping for exactly that literal — and the split is

   ```bash
   flutter test --exclude-tags "golden || watcher-live"   # local + windows CI
   flutter test --exclude-tags watcher-live               # ubuntu CI, goldens in
   ```

   `watcher-live` is the second excluded tag: those tests touch the real
   filesystem and sleep in real time to observe what the platform watcher
   reports (spike S5). They run from the dedicated `watch-observation`
   workflow, or locally with `--tags watcher-live`.
4. **Integration smoke** (`integration_test`, both OS runners): launch →
   open fixture folder → activate file → assert rendered text → restart →
   assert session restored.
5. **Architecture tests**: import-boundary scan (doc 02) + the
   no-stray-write-mode grep (doc 10).
6. **Performance gate** — the charter's scroll and first-paint budgets,
   measured on real frames via `integration_test` + `flutter drive --profile`.

   **Profile mode only**: debug numbers are meaningless and the binding
   asserts on it. Never in CI — shared runners are too noisy for frame timing
   to mean anything. This is a pre-release check on the reference machine.

   ```bash
   flutter drive --profile --driver=test_driver/perf_driver.dart      --target=integration_test/perf_gate_test.dart -d windows
   ```

   It is written to fail loudly rather than quietly when the scroll it is
   measuring did not actually happen; `docs/spike-results/S1-renderer-bakeoff.md`
   records why that mattered.

## Torture corpus (`test/fixtures/torture/`)

Deep nesting (lists 12 levels, quotes in tables), 60-column and 2,000-row
tables, 1 MB generated document (perf harness), every GFM feature page,
malformed UTF-8, zero-byte file, front-matter edge cases, `mdx/`
adversarial set (doc 04), images: missing path, oversized, remote, SVG
badge row.

## Coverage & gates

Core ≥ **85%** lines, overall ≥ **70%**, reported as a CI artifact
(doc 14). Goldens and integration smoke are release-blocking; unit failures
block every PR.

The numeric gate switches on at **M1**. Through M0 the tree is mostly
interface stubs, where a line-coverage percentage measures nothing worth
blocking a PR over — but coverage is still uploaded every run, so the number
is visible the whole way rather than appearing from nowhere at M1.

## Definition of Done (per feature)

- [ ] Behavior matches its doc section (or the doc was updated in the PR)
- [ ] Unit/widget tests added; goldens updated if rendering changed
- [ ] All strings via ARB, en complete (vi/ja before release)
- [ ] Keyboard path works; focus visible
- [ ] No new writes outside the config dir; no new network paths
- [ ] `flutter analyze` + `dart format` clean
