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
3. **Golden tests** (renderer output): torture pages rendered with the
   bundled fonts. **Run on the ubuntu CI runner only** — bundled fonts make
   goldens stable there. Mechanics: the tag is declared in `dart_test.yaml`,
   each golden file starts with `@Tags(['golden'])`, and the split is

   ```bash
   flutter test --exclude-tags golden   # local + windows CI job
   flutter test                         # ubuntu CI job, goldens included
   ```
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
