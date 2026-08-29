# 01 · Tech stack

## Toolchain

- **Flutter 3.47.1 stable**, Dart **3.13.1** bundled (verified 2026-08-23;
  3.47.1 is the hotfix released 2026-08-19). Upgrades happen deliberately,
  never implicitly on a runner.
- The dev machine runs a **system install** at `C:\Dart\flutter`. FVM is
  *optional* — reach for it only if a second Flutter version ever has to
  coexist. The binding contract either way: this file, `.fvmrc` (if it
  exists), and the `flutter-version` input in doc 14 must never disagree.
  **Since M4 that is checked rather than promised.** The version is written out
  in four places — `ci.yml`, `watch-observation.yml`, `tool/goldens/Dockerfile`
  and this line — and `test/repo/pin_agreement_test.dart` fails if any of them
  drifts. A rule that spans four files and is kept by memory is a rule that is
  already broken somewhere nobody has looked.
- **Lints:** `very_good_analysis` **10.3.0** (strict — mirrors the TS-strict
  habit), tuned in `analysis_options.yaml`. An `11.0.0-rc.1` exists;
  prereleases are not pinned.
- **State:** Riverpod **3.4.2** (`riverpod` in pure-Dart layers,
  `flutter_riverpod` at the widget edge). Note this is Riverpod **3.x** — the
  API differs materially from the v2 that most tutorials and answers assume.
  Write against v3 idioms.

## Renderer decision — **settled: `flutter_markdown_plus 1.0.12`**

Ratified 2026-08-23 after S1 and S2
(`docs/spike-results/S1-renderer-bakeoff.md`, `S2-selection.md`).

It is a Flutter *widget* package, so it may not be imported from `core/`
(rule 3). It sits behind the `MarkdownRenderer` interface in
`features/reader/rendering/`, which is the only place it is imported;
`core/markdown/` produces the pure-Dart `DocModel` it consumes. See doc 02 for
the seam and doc 04 for the pipeline.

### Why, and what it costs

Both candidates cleared every measurable gate — the fps floor by roughly an
order of magnitude, and the selection quality bar identically. Performance was
therefore not a tiebreaker, and the decision came down to maintenance.

| Candidate | Verified 2026-08-23 | Notes |
|---|---|---|
| `flutter_markdown_plus` **1.0.12** | BSD-3-Clause. Verified publisher (Foresight Mobile). Latest release ~6 weeks old. Depends only on `markdown ^7.3.1`, `meta`, `path`. | **Default favourite.** Actively maintained continuation of Google's discontinued `flutter_markdown`. GFM by default, no inline-HTML rendering (fits our policy), `MarkdownStyleSheet` + `builders` + `extensionSet` + `onTapLink` hooks, `selectable` option and documented `SelectionArea` compatibility. |
| `markdown_widget` **2.3.2+8** | MIT, verified publisher (morn.fun), but **sixteen months without a release**, and it pulls `flutter_highlight ^0.7.0` as a *hard* dependency plus `url_launcher`, `visibility_detector` and `scroll_to_index`. | **Rejected.** It measured slightly better (1:1 block list, ~17% faster first paint), but the margin is invisible against a budget both clear by 10x, and the maintenance gap is structural. Not shipped, so it is not in `legal/THIRD_PARTY_NOTICES.md`. |

Two behaviours of the winner are load-bearing and easy to break — both
measured in S1, both covered by tests:

- **Its child list is `2N-1`**, with a `SizedBox` spacer between every pair of
  real blocks. Filtering spacers out by type is unsafe: an empty heading is a
  real block that also renders as a `SizedBox`. Only `children[2i]` is correct.
- **It emits nothing at all for block HTML.** The "Raw HTML (not rendered)" box
  in doc 04 must be produced upstream in `core/markdown/`.
- **It exposes no span-level styling hook.** `MarkdownStyleSheet` maps tags to
  styles and a `MarkdownElementBuilder` is handed a whole element and the
  *block's* style, never the inline style in force — so nothing can style an
  arbitrary range of characters inside rendered prose without re-rendering the
  element and losing the bold, links and inline code inside it. Found at M2,
  when find-in-file wanted per-match highlighting; doc 08 is amended to
  block-level marking as a result. It is a property of this choice rather than
  of the feature, which is why it belongs beside the other two: a future
  renderer swap should score against it.

## Highlighting decision — **settled: `highlight 0.7.0`**

Ratified 2026-08-23 (`docs/spike-results/S1c-highlighter.md`). Note the pin is
`highlight`, the pure-Dart engine — **not** the `flutter_highlight` widget
wrapper, which is dropped. The `CodeHighlighter` seam in
`features/reader/rendering/` returns spans rather than a widget, and the
wrapper's only other contribution was 90 bundled themes; a scope → `TextStyle`
map derived from our own doc 06 tokens is more consistent, and doc 13 prefers
fifty lines of our own code over a utility dependency.

| Option | Verdict |
|---|---|
| **`highlight` 0.7.0** | MIT, unverified uploader, 5 years old, pure Dart, one dependency (`collection`). **Chosen.** An unknown language passes the code through unstyled — which *is* the `CodeHighlighter` contract, satisfying rule 9 for free — and it tokenises ~1.5× faster (16.7 ms vs 24.7 ms on 13 KB). |
| `re_highlight` 0.0.3 | MIT, verified publisher, 2 years old, tracks highlight.js v11.9.0. **Rejected.** Its whole premise was fresher grammars, and that did not survive measurement: identical scopes on Dart 3 including `sealed`/`base`/`interface`/`mixin`. It raises a hard `AssertionError` on an unknown language, and it imports `flutter/rendering` — more to break against over years than a pure-Dart tokeniser. |
| `syntax_highlight` | **Rejected twice over.** 0.5.0 cannot resolve against our pins (the same win32 chain, via `super_native_extensions` → `device_info_plus`); the 0.4.0 that does resolve ships five grammars. |

**Accepted gaps** (doc 15 asks for these in writing): no `toml` alias (`ini` is
the near equivalent and works); grammars frozen around 2020, so `wasm`, `wren`
and the REPL variants are absent; and an unverified uploader, which choosing
differently would not have fixed since it is the same uploader. Revisit if a
maintained port with a verified publisher appears.

## Dependency table

Exact versions verified on pub.dev 2026-08-23 and frozen against the committed
`pubspec.lock`. Every row is an exact pin; licenses are re-checked whenever one
moves (rule 10).

| Package | Role | License | Pin |
|---|---|---|---|
| flutter_markdown_plus | Markdown → widgets (renderer seam) | BSD-3 | `1.0.12` |
| markdown (Dart team) | Parser/AST, pure Dart (front-matter-free source) | BSD-3 | `7.3.1` |
| highlight | Code-block tokenising, pure Dart (bundles highlight.js grammars) | MIT (hl.js BSD-3) | `0.7.0` |
| flutter_svg | SVG images (badges etc.) | **MIT** | `2.3.0` |
| riverpod / flutter_riverpod | State | MIT | `3.4.2` |
| window_manager | Window geometry, minimum size, titles | **MIT** | `0.5.2` |
| watcher (Dart team) | File/folder watching | BSD-3 | `1.2.1` |
| file_picker | Open file/folder dialogs | MIT | `12.0.0` — see note |
| desktop_drop | Drag & drop onto window | **Apache-2.0** | `0.8.0` |
| path_provider | Config directory (resolved in `app/`, injected into core) | BSD-3 | `2.1.6` |
| url_launcher | External links in system browser | BSD-3 | `6.3.2` |
| args | CLI argument parsing | BSD-3 | `2.7.0` |
| path (Dart team) | Path joining/normalizing in `core/` (link routing) | BSD-3 | `1.9.1` |
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
- **`file_picker` 12 drags a `win32 ^6.3.0` chain** through
  `windows_file_picker`, and that chain has already ruled two packages out of
  this tree. `syntax_highlight` 0.5.0 cannot resolve against it at all (it
  needs `win32 ^5.x` via `super_native_extensions` → `device_info_plus`), and
  `package_info_plus` could only be held at `10.x` for the same reason —
  8.0.3–9.x want `win32 ^5.5.3`. `package_info_plus` has since been **removed**
  (M4: nothing imported it; the version is the hand-kept constant in
  `lib/app/version.dart`), so the wall is one package less crowded, but it is
  still there. Anything reaching for `win32` transitively will hit it.
- **`file_picker` 12 changed shape.** `FilePicker.pickFiles(...)` is a static
  returning `Future<List<PlatformFile>>` directly; 11 and earlier went through
  `FilePicker.platform` and returned a nullable result object. `lockParentWindow`
  moved into `WindowsOptions` / `LinuxOptions`. Wired at M1 behind
  `FilePickerPrompt` in `app/open_files.dart`, which is the only place in the
  app that touches the plugin — so a widget test can drive File → Open with a
  stub, and the next major bump is one file.
- **`desktop_drop` is Apache-2.0**, not BSD/MIT. Apache-2.0 is one-way
  compatible into GPLv3, so it is fine for a GPL-3.0-only project — recorded
  explicitly so nobody has to re-derive it later.

## Bundled fonts (identical rendering on both OSes)

- **Noto Sans** 2.015 (UI + body — full Vietnamese coverage), four faces
- **Noto Sans JP** 2.004 (Japanese fallback), Regular and Bold
- **JetBrains Mono** 2.304 (code blocks), Regular and Bold

All OFL-1.1. The licence texts ship *in the bundle* — `pubspec.yaml` lists them
under `assets:` and `lib/app/license_registry.dart` registers them, because
`LicenseRegistry` collects package licences by itself and asset licences not at
all. System-font fallback stays enabled below the bundled set for emoji and
rare scripts.

### The size decision, closed at M4

The open question from M0 was that a full Noto Sans JP is several MB and pushes
directly against charter principle 5 ("Small — in download size"), with
subsetting, the variable font and system fallback as the options, to be picked
"with real numbers before M4 packaging". The numbers:

| | Subset shipped | Upstream |
|---|---:|---:|
| Noto Sans, four faces | 738,840 | 2,538,272 |
| Noto Sans JP, two faces | 4,365,812 | 9,189,476 |
| JetBrains Mono, two faces | 338,976 | 551,728 |
| **Total** | **5,443,628** | **12,279,476** |

**Subsetting wins**, to the JIS X 0208 repertoire for Japanese and to
Latin + Latin Extended Additional for the rest. A clean Windows release build
goes from 33,910,661 to 39,352,134 bytes: **+5.19 MiB, +16.0%**.

The repertoire is derived rather than listed — every two-byte Shift-JIS
sequence, decoded — so it is 6,879 characters where a `U+4E00..U+9FFF` block
range would have been 20,992. Both subsets also union in every character in
`lib/l10n/*.arb` and the torture corpus, because a missing kanji renders a tofu
box and no test in this repo could see it.

**Accepted gaps**, in the shape S1c's highlighter gaps are recorded: kanji
outside JIS X 0208 fall through to the system font, as do scripts other than
Latin and Japanese, and emoji. That is the intended fallback behaviour rather
than a defect — the bundle exists so that Vietnamese and Japanese *documents*
render identically on both OSes, not so that MarkLens ships every script in
Unicode.

**Two alternatives were measured and rejected**, and the numbers are in
`fonts/README.md` so revisiting is cheap: JIS level 1 only saves 2.03 MB but
re-opens exactly the OS-dependent rendering the bundle removes, and dropping the
JP Bold face saves 2.21 MB at the cost of synthesised bold in every Japanese
heading. The first loses on charter priority — principle 1 outranks principle 5.
The second is a quality judgement rather than a correctness one, and is the one
to revisit first if the artefact ever has to shrink.

The variable font was not measured: `noto-cjk`'s JP variable is 8.1 MB against
4.5 MB for the static Regular, and its whole benefit is weights between 100 and
900 that a two-weight design does not use.

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
