# Changelog

All notable changes to MarkLens are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

## [Unreleased]

### Added
- Initial documentation suite v1.0 (pre-implementation).
- M0 scaffold: Flutter 3.47.1 project skeleton, exact dependency pins with a
  committed lockfile, EN/VI/JA ARB localizations, and the CI workflow.
- Architecture boundary tests: core purity (pure-Dart allowlist), feature
  isolation, read-only enforcement and zero-network enforcement. Each ships
  with tests for its own detector.
- GitHub-compatible heading slugs, including combining-mark handling for
  decomposed Vietnamese.
- Torture corpus (`test/fixtures/torture/`) with byte-exact fixtures whose
  integrity is asserted, so a `.gitattributes` regression fails loudly instead
  of turning the decoder tests into no-ops.
- Reader renderer on `flutter_markdown_plus`, syntax highlighting on the
  pure-Dart `highlight` engine, both behind their own seams.
- Menu bar (File · View · Help) with the complete `docs/06` shortcut set,
  Alt accelerators carried in the translated labels, and a conflict test that
  fires every shortcut while a text field holds focus.
- `WatchNormalizer`: collapses any editor save pattern into a single `changed`,
  classifying by whether the path exists rather than by event kind.
- Performance gate (`integration_test/perf_gate_test.dart`) for the charter's
  fps and first-paint budgets, and a manual `watch-observation` workflow that
  records platform watcher behaviour on both OSes.

### Changed
- `MarkdownRenderer` moved from `core/markdown/` to
  `features/reader/rendering/`. Rule 3 (core is pure Dart) and rule 6 (one
  renderer seam) pointed at the same directory, which no renderer package can
  satisfy; the pipeline now ends at a pure-Dart `DocModel`.
- Dependency pins corrected against pub.dev: Flutter 3.47.1, and verified
  licenses for `flutter_svg` (MIT), `window_manager` (MIT) and `desktop_drop`
  (Apache-2.0).
- `docs/06`: whole-document `SelectionArea` replaced by File → Copy entire
  document (`Ctrl+Shift+C`). Building every block so the document could be
  selected costs 527 ms to first paint at 100 KB and kills the app at 1 MB.
- `docs/06`: `Alt` opens the File menu rather than focusing the bar — Flutter's
  `MenuBar` excludes itself from the focus tree while closed.
- `docs/03` and `docs/07`: watch events are classified by whether the path
  exists when the debounce window closes, and ad-hoc files are watched through
  their parent directory — `FileWatcher` silently polls at one second on
  Windows.

### Removed
- `flutter_highlight` and `markdown_widget`, both evaluated and rejected. The
  dependency table is one package shorter than the original plan.
