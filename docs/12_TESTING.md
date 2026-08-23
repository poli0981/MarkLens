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
   states, placeholder cards, menu keyboard navigation.
3. **Golden tests** (renderer output): torture pages rendered with the
   bundled fonts. **Run on the ubuntu CI runner only** — bundled fonts make
   goldens stable there; local Windows runs skip them (`--tags=golden`).
4. **Integration smoke** (`integration_test`, both OS runners): launch →
   open fixture folder → activate file → assert rendered text → restart →
   assert session restored.
5. **Architecture tests**: import-boundary scan (doc 02) + the
   no-stray-write-mode grep (doc 10).

## Torture corpus (`test/fixtures/torture/`)

Deep nesting (lists 12 levels, quotes in tables), 60-column and 2,000-row
tables, 1 MB generated document (perf harness), every GFM feature page,
malformed UTF-8, zero-byte file, front-matter edge cases, `mdx/`
adversarial set (doc 04), images: missing path, oversized, remote, SVG
badge row.

## Coverage & gates

Core ≥ **85%** lines, overall ≥ **70%** — enforced in CI (doc 14), reported
as an artifact. Goldens and integration smoke are release-blocking; unit
failures block every PR.

## Definition of Done (per feature)

- [ ] Behavior matches its doc section (or the doc was updated in the PR)
- [ ] Unit/widget tests added; goldens updated if rendering changed
- [ ] All strings via ARB, en complete (vi/ja before release)
- [ ] Keyboard path works; focus visible
- [ ] No new writes outside the config dir; no new network paths
- [ ] `flutter analyze` + `dart format` clean
