# Third-Party Notices

MarkLens ships with the following third-party components. Licenses marked
*(verify)* are confirmed at M0 when versions are pinned (CLAUDE.md rule
10); full license texts live in `legal/licenses/` and in-app under
Help → Third-party Licenses.

| Component | Role | License |
|---|---|---|
| Flutter SDK | Framework | BSD-3-Clause |
| flutter_markdown_plus *or* markdown_widget (S1) | Markdown rendering | BSD-3-Clause / *(verify)* |
| markdown (Dart team) | Markdown parsing | BSD-3-Clause |
| flutter_highlight | Syntax highlighting | MIT |
| highlight.js (bundled by the above) | Highlight grammars/themes | BSD-3-Clause |
| flutter_svg | SVG rendering | *(verify)* |
| riverpod / flutter_riverpod | State management | MIT |
| window_manager | Window control | *(verify)* |
| watcher | File watching | BSD-3-Clause |
| file_picker | Native dialogs | MIT |
| desktop_drop | Drag & drop | *(verify)* |
| path_provider | App directories | BSD-3-Clause |
| url_launcher | External links | BSD-3-Clause |
| args | CLI parsing | BSD-3-Clause |
| package_info_plus | App version info | BSD-3-Clause |
| Noto Sans / Noto Sans JP | UI & body fonts | SIL OFL 1.1 |
| JetBrains Mono | Code font | SIL OFL 1.1 |

## Release gate

- [ ] Every shipped package appears above with a verified license
- [ ] `legal/licenses/` contains the full text for each license family
- [ ] About → Third-party lists this table with pinned versions
- [ ] Font OFL texts ship alongside the bundled font files
