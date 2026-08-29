# Third-Party Notices

MarkLens ships with the following third-party components. Licenses and
versions below were verified on pub.dev on **2026-08-23**; they are re-checked
whenever a pin moves (CLAUDE.md rule 10). Full license texts live in
`legal/licenses/` and in-app under Help → Third-party Licenses.

| Component | Role | License | Version |
|---|---|---|---|
| Flutter SDK | Framework | BSD-3-Clause | 3.47.1 |
| flutter_markdown_plus | Markdown rendering | BSD-3-Clause | 1.0.12 |
| markdown (Dart team) | Markdown parsing | BSD-3-Clause | 7.3.1 |
| highlight | Syntax highlighting (tokeniser, pure Dart) | MIT | 0.7.0 |
| highlight.js (grammars bundled by the above) | Highlight grammars | BSD-3-Clause | — |
| flutter_svg | SVG rendering | MIT | 2.3.0 |
| riverpod / flutter_riverpod | State management | MIT | 3.4.2 |
| window_manager | Window control | MIT | 0.5.2 |
| watcher | File watching | BSD-3-Clause | 1.2.1 |
| file_picker | Native dialogs | MIT | 12.0.0 |
| desktop_drop | Drag & drop | **Apache-2.0** | 0.8.0 |
| path_provider | App directories | BSD-3-Clause | 2.1.6 |
| url_launcher | External links | BSD-3-Clause | 6.3.2 |
| args | CLI parsing | BSD-3-Clause | 2.7.0 |
| path (Dart team) | Path resolution | BSD-3-Clause | 1.9.1 |
| Noto Sans | UI & body font (subset, four faces) | SIL OFL 1.1 | 2.015 |
| Noto Sans JP | Japanese fallback (subset, two faces) | SIL OFL 1.1 | 2.004 |
| JetBrains Mono | Code font (subset, two faces) | SIL OFL 1.1 | 2.304 |

All package rows are frozen to the exact version in the committed
`pubspec.lock`. The S1 bake-off closed at M0 and `markdown_widget` does not
ship, so it is not listed; doc 01 records why it lost.

The three fonts are **subsets** built by `tool/fonts/build_fonts.py` from the
pinned upstream releases in `fonts/README.md`, and their versions above are what
each font's own `name` table reports. Copyright, likewise from the fonts
themselves:

- Noto Sans — Copyright 2022 The Noto Project Authors
- Noto Sans JP — © 2014–2021 Adobe (http://www.adobe.com/)
- JetBrains Mono — Copyright 2020 The JetBrains Mono Project Authors

The OFL permits subsetting and requires the licence to travel with the font;
`legal/licenses/OFL-1.1-*.txt` ship inside the bundle for that reason, not as
documentation.

## License compatibility notes

- The project is **GPL-3.0-only**. BSD-3-Clause, MIT and SIL OFL 1.1 are all
  permissive and combine into GPLv3 without friction.
- **desktop_drop is Apache-2.0.** Apache-2.0 is one-way compatible *into*
  GPLv3 (it is not compatible with GPLv2), so it is fine here. Recorded
  explicitly so nobody has to re-derive it during a release review.
- `flutter_svg` pulls **`http`** transitively. It ships in the binary, so it
  is disclosed here (resolved: `http 1.6.0`) even though MarkLens never calls it — see
  `docs/10_SECURITY_PRIVACY.md` for how that is kept true.

## Release gate

- [ ] Every shipped package appears above with a verified license and version
- [x] `legal/licenses/` contains the full text for each license family
      (BSD-3-Clause, MIT, Apache-2.0, SIL OFL 1.1) — added at M4, with
      `legal/licenses/README.md` recording which package each family text was
      copied from
- [ ] About → Third-party lists this table with pinned versions
- [x] Font OFL texts ship alongside the bundled font files — in the bundle
      itself via `pubspec.yaml` `assets:`, and surfaced through
      `lib/app/license_registry.dart`; asserted by
      `test/app/license_registry_test.dart`
