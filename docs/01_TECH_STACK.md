# 01 · Tech stack

## Toolchain

- **Flutter 3.47.1 stable**, Dart **3.13.1** bundled (verified 2026-08-23;
  3.47.1 is the hotfix released 2026-08-19). Upgrades happen deliberately,
  never implicitly on a runner.
- The dev machine runs a **system install** at `C:\Dart\flutter`. FVM is
  *optional* — reach for it only if a second Flutter version ever has to
  coexist. The binding contract either way: this file, `.fvmrc` (if it
  exists), and the `flutter-version` input in doc 14 must never disagree.
- **Lints:** `very_good_analysis` **10.3.0** (strict — mirrors the TS-strict
  habit), tuned in `analysis_options.yaml`. An `11.0.0-rc.1` exists;
  prereleases are not pinned.
- **State:** Riverpod **3.4.2** (`riverpod` in pure-Dart layers,
  `flutter_riverpod` at the widget edge). Note this is Riverpod **3.x** — the
  API differs materially from the v2 that most tutorials and answers assume.
  Write against v3 idioms.

## Renderer decision (gated by Spike S1)

Both candidates are Flutter *widget* packages, so neither may be imported from
`core/` (rule 3). They sit behind the `MarkdownRenderer` interface in
`features/reader/rendering/`; `core/markdown/` produces the pure-Dart
`DocModel` they consume. See doc 02 for the seam and doc 04 for the pipeline.

| Candidate | Verified 2026-08-23 | Notes |
|---|---|---|
| `flutter_markdown_plus` **1.0.12** | BSD-3-Clause. Verified publisher (Foresight Mobile). Latest release ~6 weeks old. Depends only on `markdown ^7.3.1`, `meta`, `path`. | **Default favourite.** Actively maintained continuation of Google's discontinued `flutter_markdown`. GFM by default, no inline-HTML rendering (fits our policy), `MarkdownStyleSheet` + `builders` + `extensionSet` + `onTapLink` hooks, `selectable` option and documented `SelectionArea` compatibility. |
| `markdown_widget` **2.3.2+8** | MIT (was *verify* — now confirmed). Verified publisher (morn.fun). **Last release ~16 months ago.** Pulls in `flutter_highlight ^0.7.0`, `url_launcher`, `visibility_detector`, `scroll_to_index`. | **Candidate B, materially weaker.** Has TOC + lazy block-list rendering, which is genuinely relevant to doc 04. But the maintenance gap and the heavier dependency tree both count against it. Score it honestly; do not pick it on features alone. |

S1 measures fidelity + scroll performance on the torture corpus (doc 12) and
selection quality (S2); the winner is recorded here with its exact pin.

## Highlighting decision (also gated by S1)

`flutter_highlight` is the ecosystem default and its latest release is **five
years old**, from an **unverified uploader**, wrapping highlight.js grammars
frozen around 2020 (no Dart 3 syntax, none of the languages added since). That
is known debt taken deliberately, not an oversight: it is pinned at M0 so the
scaffold builds, and it sits behind a `CodeHighlighter` interface in
`features/reader/rendering/` so replacing it touches one file.

| Option | Verified 2026-08-23 | Notes |
|---|---|---|
| `flutter_highlight` **0.7.0** | MIT, published 5 years ago, unverified uploader, ~235k downloads | Incumbent / M0 pin. Thin widget wrapper over the pure-Dart `highlight` package — the token engine could be lifted into a pure layer if wanted. |
| `re_highlight` **0.0.3** | MIT, verified publisher (Reqable.com), published 2 years ago | Dart port of highlight.js **v11.9.0** — far newer grammars, full test suite ported. But `0.0.x` and low adoption: trading one risk for another. |
| `syntax_highlight` **0.5.0** | BSD-3, verified publisher (serverpod.dev), 12 months old | TextMate grammars (VS Code style), well maintained — but only ~15 languages, and it pulls `super_clipboard`, which adds a native/Rust build step. Too narrow and too heavy for a general-purpose viewer. |

S1 records the winner, its exact pin, and the language-coverage gap accepted.

## Dependency table

Exact versions verified on pub.dev 2026-08-23 and frozen against the committed
`pubspec.lock`. Every row is an exact pin; licenses are re-checked whenever one
moves (rule 10).

| Package | Role | License | Pin |
|---|---|---|---|
| flutter_markdown_plus *or* markdown_widget | Markdown → widgets (renderer seam) | BSD-3 / MIT | S1 (`1.0.12` provisional) |
| markdown (Dart team) | Parser/AST, pure Dart (front-matter-free source) | BSD-3 | `7.3.1` |
| flutter_highlight | Code-block highlight (bundles highlight.js) | MIT (hl.js BSD-3) | `0.7.0` — provisional, see above |
| flutter_svg | SVG images (badges etc.) | **MIT** | `2.3.0` |
| riverpod / flutter_riverpod | State | MIT | `3.4.2` |
| window_manager | Window geometry, minimum size, titles | **MIT** | `0.5.2` |
| watcher (Dart team) | File/folder watching | BSD-3 | `1.2.1` |
| file_picker | Open file/folder dialogs | MIT | `12.0.0` — major bump 2026-08; read its CHANGELOG before wiring |
| desktop_drop | Drag & drop onto window | **Apache-2.0** | `0.8.0` |
| path_provider | Config directory (resolved in `app/`, injected into core) | BSD-3 | `2.1.6` |
| url_launcher | External links in system browser | BSD-3 | `6.3.2` |
| args | CLI argument parsing | BSD-3 | `2.7.0` |
| package_info_plus | Version for About/update check | BSD-3 | `10.2.1` — see note |
| flutter_localizations + intl | i18n | SDK / BSD-3 | SDK / `0.20.3` |

Notes that matter:

- `flutter_markdown_plus` depends on `markdown ^7.3.1` — the same package
  `core/markdown/` uses directly. No version conflict, one parser in the
  binary.
- **`flutter_svg` pulls `http` transitively.** That is a network-capable
  package inside a zero-network-by-default app. `SvgPicture.network`,
  `Image.network` and `NetworkImage` are therefore banned outside the
  remote-image path, and `test/architecture/no_network_test.dart` enforces it
  (doc 10, invariant 4).
- **`package_info_plus` is held at `10.x` by `file_picker`.** `file_picker`
  12 requires `win32 ^6.3.0` via `windows_file_picker`, while
  `package_info_plus` 8.0.3–9.x requires `win32 ^5.5.3`. They cannot coexist;
  `package_info_plus 10.2.1` is the version that resolves. Recorded because
  the next person to bump either package will hit the same wall.
- **`desktop_drop` is Apache-2.0**, not BSD/MIT. Apache-2.0 is one-way
  compatible into GPLv3, so it is fine for a GPL-3.0-only project — recorded
  explicitly so nobody has to re-derive it later.

## Bundled fonts (identical rendering on both OSes)

- **Noto Sans** (UI + body — full Vietnamese coverage)
- **Noto Sans JP** (Japanese fallback)
- **JetBrains Mono** (code blocks)

All OFL-1.1; license files ship in `legal/licenses/` and the About screen.
System-font fallback stays enabled below the bundled set for emoji and rare
scripts.

**Open decision (deferred past M0):** a full Noto Sans JP is several MB and
pushes directly against charter principle 5 ("Small — in download size").
Subsetting, the variable font, or falling back to the system JA font are the
options; pick one with real numbers before M4 packaging.

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
- **`http` as a direct dependency** — the update check uses `dart:io`
  `HttpClient`. `http` arriving transitively via `flutter_svg` is tolerated;
  reaching for it directly is not.
- **Electron-style rewrites, obviously.**
