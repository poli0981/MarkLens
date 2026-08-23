# 15 · P0 spikes & roadmap

Feature work does not start until S1–S5 pass. Each spike is a throwaway
branch with a written result note committed to `docs/spike-results/`.

## S1 — Renderer bake-off *(the decision spike)*

Render the torture corpus (doc 12) with `flutter_markdown_plus` and
`markdown_widget`.
**Pass:** GFM checklist fully correct (tables incl. wide-scroll, task
lists, fenced code, images, footnote behavior recorded either way); 1 MB
document scrolls ≥ 55 fps average on the dev machine; styling hooks
sufficient for the doc 06 theme tokens. **Output:** winner + exact pin
recorded in doc 01, wrapper notes for `MarkdownRenderer`.
Also verify `markdown_widget` maintenance status/license before scoring it.

## S2 — Selection & copy quality

Wrap the S1 winner's output in `SelectionArea`; also test its native
`selectable` mode.
**Pass:** select across heading + paragraph + code block + table cell
yields clean clipboard text (newlines sane, no widget artifacts); VI
diacritics and JA text select correctly; code-block copy button preserves
formatting exactly. **Fail here = revisit S1 choice before anything else.**

## S3 — Ubuntu clean-VM run

Fresh Ubuntu 24.04 VM (and a 22.04 check for the floor).
**Pass:** debug build launches; bundled Noto fonts render VI/JA correctly;
file/folder dialogs work; watcher fires on ext4; AppImage produced from the
22.04 runner recipe launches on both VMs.

## S4 — Menu bar + shortcuts prototype

Build the custom menu bar skeleton with 5 real items and the doc 06
shortcut set.
**Pass:** full keyboard traversal (Alt, arrows, Esc), no shortcut conflicts
with Flutter defaults, and it *feels* right — subjective gate, Kokone
decides.

## S5 — Watcher save-pattern matrix

Save files from VS Code, Notepad++ and vim on Windows/NTFS; VS Code and vim
on Ubuntu/ext4, against the WatchService normalizer.
**Pass:** every save lands as a single `changed` within 500 ms, or the miss
is documented and caught by the focus-sweep fallback (doc 03). No
false `missing` badges during atomic saves.

## Roadmap

| Milestone | Contents | Est. |
|---|---|---|
| **M0** | Spikes S1–S5, pin toolchain + deps (doc 01), scaffold repo + CI stub | 1 wk |
| **M1 — usable daily** | Open file/folder, sidebar + tabs, pipeline + reader, session restore, single instance + CLI | 2 wk |
| **M2 — comfortable** | Watch/auto-reload, outline, Ctrl+F, zoom, themes, front-matter panel | 1.5 wk |
| **M3 — complete** | Cross-file search + Ctrl+P, MDX placeholders, link routing, file association, Settings UI, i18n vi/ja | 1.5 wk |
| **M4 — shipped** | Packaging both OSes, A-1 reusable workflow, docs polish, v1.0.0 | 1 wk |

~7 focused weeks; solo-dev buffer applies. M1 is the "start living in it"
gate — daily use from M1 onward is the real QA.

## Release checklist (every tag)

- [ ] Version bumped in `pubspec.yaml`; CHANGELOG section written
- [ ] Full suite green incl. goldens + integration on both runners
- [ ] vi/ja translations complete for new strings
- [ ] Read-only audit: write-grep test green + manual ProcMon/strace pass (doc 10)
- [ ] Artifacts smoke-tested on clean Windows VM + Ubuntu 24.04 VM
- [ ] `SHA256SUMS` verified; release notes written; tag `vx.y.z`; publish draft
- [ ] Listings updated: SoftHarbor entry + poli0981.dev portfolio
- [ ] Post-release: file association behaves after real install; update
      banner fires from the previous version
