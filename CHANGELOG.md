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

- `core/markdown/` completed for M1: front-matter splitting, the block index,
  the heading outline with GitHub slugs, and a block-HTML pre-pass. The
  pipeline now produces a real `DocModel` instead of three placeholders.
- Block HTML — and block-level `<Component>` tags in `.mdx`, which CommonMark
  classifies the same way — is rewritten into an inert fenced block instead of
  being deleted without trace by the renderer.
- `DocModel.rawSource`, the file exactly as decoded, so File → Copy entire
  document copies the whole document rather than a version with the front
  matter stripped.
- One pinned Markdown flavour shared by `core/markdown/` and the renderer, so
  the two parses cannot silently disagree about where blocks begin.
- ARB strings (en/vi/ja) for every `DocNoticeKind`, held to the enum by an
  exhaustive switch so a new kind without a translation fails to compile.

- `FileService`: breadth-first folder scan with the extension registry, natural
  sort, the soft 1,000-entry cap that reports rather than truncating, symlinked
  directories skipped for cycle safety, and an isolate entry point for big
  trees. `OpenedFile` carries both a display path and a canonical identity,
  because the sidebar needs the casing the user chose and the open set needs a
  key that a symlink cannot duplicate.
- `DocCache`: LRU of parsed documents, forty by default, keyed on
  `identity + mtime + size + settingsRevision`.
- `SettingsStore` and `SessionStore` over one atomic `JsonStore` — temp file,
  flush, rename — with corruption quarantined rather than deleted, a newer
  schema backed up rather than read, and session writes debounced to one
  second so a scroll never reaches the disk.
- Core services wired into `app/providers.dart`.
- The reader: notice bar, front-matter panel, code blocks with a language
  label and a copy button, and the collapsed "Raw HTML (not rendered)" box.
- **File → Open opens a document**, and the app shows it — the shell had no
  document view until now. Reload and Copy entire document work with it.
- The eight doc 06 theme tokens, light and dark, with their WCAG contrast
  asserted by a test rather than judged by eye. This closes the last open
  criterion of spike S1, which was waiting on them.

### Changed
- The parsed-document cache key is `identity + mtime + size +
  settingsRevision`. Doc 02, doc 03 and doc 07 each specified a different key;
  this is the reconciliation, and all four docs now say the same thing. Size is
  in it because doc 07's own tuple exists to catch a rewrite inside one
  timestamp tick, which mtime alone would miss.
- `DocModel.blocks` may now be empty. "Every document has at least one block"
  was not true: an empty file, a file of blank lines and a file of nothing but
  link-reference definitions all render as nothing, and the block list has to
  match the renderer's child list exactly.
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
