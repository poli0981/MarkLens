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
3. **Golden tests.** Two kinds, and the distinction matters even now that both
   exist: one pins geometry and is font-free, the other pins typography and
   therefore loads the fonts itself.

   **Layout goldens** — `test/goldens/shell_chrome_golden_test.dart`, the first
   goldens in the repo, added at M2. They pin the chrome the first visual pass
   found broken: where the menu bar starts and how wide it runs, and which
   fields the status bar shows in what order. They depend on no font, because
   `flutter_test` substitutes its own fixed-width test font, and on no
   filesystem — every fixture is a literal, since a golden that embeds
   `Directory.systemTemp` differs between the dev machine and the runner.

   **That font claim was re-checked at M4 and held**, which was not the
   expectation. Bundling three families and setting `fontFamily` on both themes
   looked certain to re-bless all five images. It changed nothing: a widget test
   renders `Noto Sans`, `JetBrains Mono` and a deliberately invented family name
   to *identical* widths, because `flutter test` does not load the fonts
   `pubspec.yaml` declares — every family resolves to the test font. Measured
   before the change and confirmed after it, in the container.

   The consequence matters more for the renderer goldens than for these: a
   golden that is supposed to prove Vietnamese and Japanese render correctly
   proves nothing at all unless it loads the real fonts itself, with a
   `FontLoader`. Loading them globally would make every layout golden
   font-dependent, so it belongs in the renderer golden file rather than in a
   suite-wide `flutter_test_config.dart`.

   **Renderer goldens** — `test/goldens/renderer_golden_test.dart`, written at
   M4 once the fonts landed. Eleven pages: Vietnamese and Japanese (light and
   dark, and one with the front-matter panel open), the GFM headings, lists,
   fenced-code and tables pages, the footnote/raw-HTML page, the MDX
   placeholders, and deep nesting. Each is the real `ReaderView` at the doc 06
   reading column, 760×720.

   **This file loads the fonts itself, and has to.** `flutter test` does not
   load the families `pubspec.yaml` declares, so a renderer golden taken without
   a `FontLoader` is a picture of the substituted test font — it would pass, and
   prove nothing. Scoped to the one file rather than a suite-wide
   `flutter_test_config.dart`, which would make the layout goldens
   font-dependent for no benefit.

   The Japanese page earns its place twice over. The bundled Noto Sans JP is a
   JIS X 0208 subset, and a kanji outside that repertoire falls through to the
   system font — a tofu box on a machine without one. No behavioural test can
   see that; `tool/fonts/build_fonts.py` unions every character of this corpus
   into the subset precisely because it cannot, and this golden is the only
   mechanical check that the union held.

   The two i18n fixtures were added with them:
   `test/fixtures/torture/i18n/{vietnamese,japanese}.md`. The corpus carried
   only a handful of VI/JA characters before, scattered through the GFM
   pages — enough to exercise a decoder, not enough to photograph a typeface.

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

   **Not written as of M4.** See "What actually gates" below for what stands in
   its place and why the restart half cannot simply be one `integration_test`.
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

Core ≥ **85%** lines, overall ≥ **70%**, reported as a CI artifact (doc 14).
Unit failures block every PR.

### What actually gates, as of M4

This section described intent for four milestones and is now written against
the pipeline that exists, because a gate nobody enforces is worse than an
absent one — it is an absent one that people believe in.

| Gate | State |
|---|---|
| Unit, widget, architecture and repo tests | **Enforced**, both runners, every PR |
| Goldens (layout and renderer) | **Enforced**, `golden (ubuntu-24.04)`, every PR |
| l10n parity and tri-locale layout | **Enforced**, part of the ordinary suite |
| Artefacts build and start | **Enforced** by `release.yml` — `dpkg -i`, then `--version` under `xvfb`, for the `.deb` and the AppImage |
| Coverage thresholds | **Not enforced.** `coverage/lcov.info` is uploaded every run and gated by nothing. This has said "switches on at M1" since M0 |
| Integration smoke (pyramid item 4) | **Not written.** See below |
| Performance gate | Deliberately never in CI — profile mode, reference machine |

**The integration smoke is the one real hole**, and it is worth being precise
about its shape rather than implying it is covered. Item 4 wants *launch → open
fixture folder → activate file → assert rendered text → restart → assert
session restored*, and none of that exists as an automated test. What does
exist: the release workflow proves the packaged binaries start and answer
`--version`, and the maintainer verified the full path — a second launch
forwarding its arguments, `session.json` afterwards — against the real binary
by hand at M1 and again at M3 (doc 15).

The restart half is also the half that cannot simply be written as one
`integration_test`: a "restart" inside one test process reuses the same isolate
and the same open file handles, so it would pass while the real thing was
broken. It needs a script that runs the built binary twice against a temp
config directory. That is real work, it is not done, and doc 15 records it as
outstanding rather than this document implying otherwise.

## Definition of Done (per feature)

- [ ] Behavior matches its doc section (or the doc was updated in the PR)
- [ ] Unit/widget tests added; goldens updated if rendering changed
- [ ] All strings via ARB, en complete (vi/ja before release)
- [ ] Keyboard path works; focus visible
- [ ] No new writes outside the config dir; no new network paths
- [ ] `flutter analyze` + `dart format` clean
