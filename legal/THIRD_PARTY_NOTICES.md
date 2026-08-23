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
| flutter_highlight | Syntax highlighting | MIT | 0.7.0 |
| highlight.js (bundled by the above) | Highlight grammars/themes | BSD-3-Clause | — |
| flutter_svg | SVG rendering | MIT | 2.3.0 |
| riverpod / flutter_riverpod | State management | MIT | 3.4.2 |
| window_manager | Window control | MIT | 0.5.2 |
| watcher | File watching | BSD-3-Clause | 1.2.1 |
| file_picker | Native dialogs | MIT | 12.0.0 |
| desktop_drop | Drag & drop | **Apache-2.0** | 0.8.0 |
| path_provider | App directories | BSD-3-Clause | 2.1.6 |
| url_launcher | External links | BSD-3-Clause | 6.3.2 |
| args | CLI parsing | BSD-3-Clause | 2.7.0 |
| package_info_plus | App version info | BSD-3-Clause | 10.2.1 |
| Noto Sans / Noto Sans JP | UI & body fonts | SIL OFL 1.1 | — |
| JetBrains Mono | Code font | SIL OFL 1.1 | — |

Only one of the two S1 candidates ships in a release; both are listed while
the bake-off is open. All rows are now frozen to the exact version in the committed `pubspec.lock`.

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
- [ ] `legal/licenses/` contains the full text for each license family
      (BSD-3-Clause, MIT, Apache-2.0, SIL OFL 1.1)
- [ ] About → Third-party lists this table with pinned versions
- [ ] Font OFL texts ship alongside the bundled font files
