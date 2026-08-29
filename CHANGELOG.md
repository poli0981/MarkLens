# Changelog

All notable changes to MarkLens are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/).

## [1.0.0] - 2026-08-29

The first release. Everything in the charter's v1 scope, packaged for both
operating systems.

### Added — M4, "shipped"

- **Four release artefacts**, built and started in CI on every release run: an
  Inno Setup installer and a portable zip for Windows, a `.deb` and an AppImage
  for Linux, with `SHA256SUMS` over all of them. The Linux pair is built inside
  an `ubuntu:22.04` container rather than on a runner of that name, so the
  glibc floor is a property of an image this repo pins.
- **A MarkLens icon.** `windows/runner/resources/app_icon.ico` had been
  byte-identical to the Flutter template's since M0. The set is now generated
  from one master, including the Linux hicolor sizes and a scalable SVG.
- **Bundled fonts** — Noto Sans, Noto Sans JP and JetBrains Mono, subset to
  5.4 MB from 12.3 MB, closing doc 01's Noto Sans JP size question with
  measurements. Vietnamese and Japanese now render identically on both
  operating systems, which is the charter's first principle.
- **Renderer goldens**, the kind doc 12 has described since M0 and could not
  have until the fonts landed: eleven pages including Vietnamese and Japanese.
- **`release.yml`**, with `contents: write` scoped to a single publish job, both
  build tools pinned by digest, and a draft that only a person can publish.
- **File associations wired**, not merely authored: the ProgId for `.md` and
  `.mdx` on Windows, and the desktop entry, MIME definitions and AppStream
  metadata on Linux.

### Fixed — M4

- The program called itself `marklens` in the taskbar, in alt-tab and in
  Explorer's Description column. It is `MarkLens` now; the executable stays
  lowercase.
- `LegalCopyright` claimed "All rights reserved" on a GPL-3.0-only binary — a
  false licence statement inside the exe's own metadata.
- `StartupWMClass` had never matched the class GTK actually advertises, so the
  Linux window did not group under its own launcher.
- Twelve golden *failure* dumps had been committed since M2 and nothing noticed,
  because a binary file nobody opens is invisible in review.

### Removed — M4

- `package_info_plus`, pinned since M0 and imported by nothing. Removing it
  saved ninety bytes, because the tree-shaker had already removed the code; the
  reason to remove it was one less unreviewed dependency and one less version
  constraint.

### Added — M3, "complete"

- **MDX placeholders.** `MdxSanitizer` is doc 04's five transforms rather than
  a pass-through: ESM lines removed and counted, block components as collapsed
  placeholder cards, inline components and braced expressions as inert code
  spans, and a fenced `mdx` bail-out for anything ambiguous.
- **Link routing.** `#anchor`, relative `.md`/`.mdx`, `http(s)` to the browser,
  and everything else refused with a notice — with the refusal made structural
  rather than procedural (doc 10, invariant 2).
- **Images.** Local by default, extension-allowlisted, size-capped with a
  load-anyway affordance, SVG, and remote images blocked behind
  `network.allowRemoteImages`.
- **Search across open files** (`Ctrl+Shift+F`), isolate-backed, results
  grouped by file with a context line.
- **Quick switcher** (`Ctrl+P`) over open and recent documents, with a fuzzy
  scorer that prefers filenames and word boundaries.
- **A recent list that survives closing a file**, read by `Ctrl+P`, File →
  Open Recent, and the first-run empty state.
- **Update check** — GitHub Releases, at most daily, setting-controlled, no
  downloading — with a passive banner and a Help menu item that always answers.
- **About**, third-party licenses, and a diagnostic-log export over a 500-entry
  in-memory ring buffer.
- **Settings** (`Ctrl+,`), covering every field in the `settings.json` schema.
- **Drag and drop**, a missing-file tab body, the sidebar context menu, and the
  50 MB refusal.
- **File-association assets** in `packaging/` for the M4 installers.

### Fixed — M3

- The recent list was derived from the open set, so closing a file erased it
  from "recent".
- `language`, `restoreSession`, `files.extensions` and `files.fileCap` were
  written to `settings.json` and read by nothing.
- A Vietnamese `#anchor` crashed the link classifier: `Uri.decodeComponent`
  raises on any code unit above 127.
- A Windows drive letter was read as a URI scheme, so `C:/docs/README.md` was
  refused as an unknown protocol.
- A protocol-relative image `src` or a UNC path reached the *local* branch,
  where statting it opens an SMB connection to a host the document named.

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
- **Sidebar and tabs**: an open set with pinning, MRU cycling, reopen, the
  missing badge and the changed-on-disk dot. Opening a folder groups its files
  under a header and asks before opening more than the cap allows.
- **Single instance, CLI arguments and session restore**, which closes M1.
  `marklens README.md` while MarkLens is running adds a tab to the window that
  is already open rather than starting a second copy; `--help` and `--version`
  print and exit; what was open comes back on the next launch, with its pins
  and its scroll positions.

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
