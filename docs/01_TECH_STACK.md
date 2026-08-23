# 01 · Tech stack

## Toolchain

- **Flutter 3.44.x stable** (Dart SDK bundled). Pin the exact hotfix at M0
  via FVM and record it here + in CI. Flutter now follows a CalVer-style
  scheme; upgrades happen deliberately, never implicitly on a runner.
- **Lints:** `very_good_analysis` (strict — mirrors the TS-strict habit),
  tuned in `analysis_options.yaml`.
- **State:** Riverpod (`riverpod` in pure-Dart layers, `flutter_riverpod`
  at the widget edge).

## Renderer decision (gated by Spike S1)

Two candidates, both wrapped behind `MarkdownRenderer` so the choice stays
reversible:

| Candidate | Status (verified 2026-08-23) | Notes |
|---|---|---|
| `flutter_markdown_plus` | Actively maintained continuation by Foresight Mobile after Google discontinued the original `flutter_markdown`. BSD-3-Clause. GFM by default, built on the Dart `markdown` package, no inline-HTML rendering (fits our policy), table styling + horizontal-scroll improvements, `selectable` option. | Default favourite — pedigree of the original, active triage. |
| `markdown_widget` | Community package; TOC support and lazy block-list rendering. **Verify maintenance status and license at S1** before considering. | Candidate B. |

S1 measures fidelity + scroll performance on the torture corpus (doc 12) and
selection quality (S2); the winner is recorded here with its exact pin.

## Dependency table

Pins marked *M0* are set (latest stable) when the lockfile is first
committed; licenses re-verified then per rule 10.

| Package | Role | License | Pin |
|---|---|---|---|
| flutter_markdown_plus *or* markdown_widget | Markdown → widgets | BSD-3 / verify | S1 |
| markdown (Dart team) | Parser/AST (front-matter-free source) | BSD-3 | M0 |
| flutter_highlight | Code-block syntax highlight (bundles highlight.js) | MIT (hl.js BSD-3) | M0 |
| flutter_svg | SVG images (badges etc.) | verify | M0 |
| riverpod / flutter_riverpod | State | MIT | M0 |
| window_manager | Window geometry, minimum size, titles | verify | M0 |
| watcher (Dart team) | File/folder watching | BSD-3 | M0 |
| file_picker | Open file/folder dialogs | MIT | M0 |
| desktop_drop | Drag & drop onto window | verify | M0 |
| path_provider | Config directory | BSD-3 | M0 |
| url_launcher | External links in system browser | BSD-3 | M0 |
| args | CLI argument parsing | BSD-3 | M0 |
| package_info_plus | Version for About/update check | BSD-3 | M0 |
| flutter_localizations + intl | i18n | SDK / BSD-3 | SDK |

## Bundled fonts (identical rendering on both OSes)

- **Noto Sans** (UI + body — full Vietnamese coverage)
- **Noto Sans JP** (Japanese fallback)
- **JetBrains Mono** (code blocks)

All OFL-1.1; license files ship in `legal/licenses/` and the About screen.
System-font fallback stays enabled below the bundled set for emoji and rare
scripts.

## Version pinning policy

Exact versions in `pubspec.yaml` (`x.y.z`, no carets), lockfile committed.
Upgrades happen in a monthly batch PR: run `flutter pub outdated`, bump,
re-verify licenses for anything new, run the full test suite + goldens.
Never upgrade during feature work.

## Explicitly rejected

- **Webview / JS engine of any kind** — violates render-not-run (doc 10).
- **flutter_markdown (original)** — discontinued by Google; do not depend on
  it even transitively if avoidable.
- **flutter_html** — HTML is deliberately not rendered (doc 04).
- **Electron-style rewrites, obviously.**
