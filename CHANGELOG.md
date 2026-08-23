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

### Changed
- `MarkdownRenderer` moved from `core/markdown/` to
  `features/reader/rendering/`. Rule 3 (core is pure Dart) and rule 6 (one
  renderer seam) pointed at the same directory, which no renderer package can
  satisfy; the pipeline now ends at a pure-Dart `DocModel`.
- Dependency pins corrected against pub.dev: Flutter 3.47.1, and verified
  licenses for `flutter_svg` (MIT), `window_manager` (MIT) and `desktop_drop`
  (Apache-2.0).
