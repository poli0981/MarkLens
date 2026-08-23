# MarkLens

**Project:** MarkLens — a fast, lightweight, read-only Markdown viewer
**Repo:** `poli0981/MarkLens`
**Platforms:** Windows 10+ · Ubuntu 22.04+ (Linux desktop)
**Stack:** Flutter 3.47.1 stable / Dart 3.13.1 · **License:** GPL-3.0-only
**Suite version:** 1.0 · **Date:** 2026-08-23
**Status:** M0 — repo scaffolded, architecture boundaries under test. P0 spikes (doc 15) must pass before feature work.

MarkLens opens `.md` / `.mdx` files or whole folders and renders them
faithfully — nothing more. It is a *viewer*, the way SumatraPDF is a viewer:
instant to open, remembers your session, never touches your files.

## Core promises

- **Read-only, always.** MarkLens never creates, modifies, or deletes user
  documents. The only writes are its own config/session files.
- **Render, not run.** MDX components and embedded HTML are displayed as inert
  placeholders — no JavaScript engine, no webview, ever.
- **Offline by default.** Zero network traffic except two opt-in features:
  the update check and remote images (off by default).
- **Identical output on both OSes.** Flutter's own renderer + bundled fonts
  mean a document looks the same on Windows and Ubuntu.

## v1 features

Open files or folders (up to 1,000 entries, soft cap) · session restore
(tabs, scroll positions, window geometry) · sidebar tree + tab strip +
quick switcher (Ctrl+P) · outline/TOC panel · find in file (Ctrl+F) and
across open files (Ctrl+Shift+F) · auto-reload on external change ·
zoom, light/dark/system themes · GFM rendering with syntax-highlighted
code blocks, SVG images, YAML front-matter panel · relative `.md` links
open in-app · full keyboard navigation · EN/VI/JA interface.

Non-goals for v1: editing of any kind, sync/cloud, plugins, export,
WYSIWYG. See `docs/00_CHARTER.md`.

## Build quickstart

```bash
flutter --version        # 3.47.1 stable — exact pin in docs/01_TECH_STACK.md
flutter pub get
flutter analyze && dart format --set-exit-if-changed .
flutter test
flutter build windows    # or: flutter build linux
```

Packaging (Inno Setup, AppImage, .deb) is documented in
`docs/11_PACKAGING_UPDATE.md`. Release artifacts for Linux are built in CI,
not on the Windows dev machine.

## Documentation map

| Doc | Contents |
|---|---|
| `CLAUDE.md` | Hard rules and workflow for AI-assisted development |
| `docs/00_CHARTER.md` | Product principles, scope, non-goals, success criteria |
| `docs/01_TECH_STACK.md` | Locked stack, dependency table, pinning policy |
| `docs/02_ARCHITECTURE.md` | Layers, repo structure, module boundary rules |
| `docs/03_DATA_FLOW.md` | Startup, open, parse, watch, save, link flows |
| `docs/04_MARKDOWN_PIPELINE.md` | Parsing stages, GFM matrix, MDX placeholder spec, images |
| `docs/05_SESSION_AND_SETTINGS.md` | `session.json` / `settings.json` schemas, migration |
| `docs/06_UI_UX.md` | Layout, menu map, shortcuts, themes, a11y |
| `docs/07_FILES_AND_WATCH.md` | Extension registry, folder scan, 1,000 cap, watcher |
| `docs/08_SEARCH.md` | Find-in-file, cross-file search, quick switcher |
| `docs/09_I18N.md` | ARB workflow for EN/VI/JA |
| `docs/10_SECURITY_PRIVACY.md` | Threat model, invariants, network policy |
| `docs/11_PACKAGING_UPDATE.md` | Installers, file association, update check |
| `docs/12_TESTING.md` | Test pyramid, torture corpus, golden policy, DoD |
| `docs/13_CODE_QUALITY.md` | Lints, naming, commit conventions |
| `docs/14_CI_CD.md` | Caller stubs, reusable-workflow gap, release pipeline |
| `docs/15_SPIKES_ROADMAP.md` | P0 spikes S1–S5, milestones M0–M4, release checklist |
| `legal/` | PRIVACY, EULA, DISCLAIMER, THIRD_PARTY_NOTICES |

## License

GPL-3.0-only. Full license text is in `LICENSE` at the repo root.

---

*Repository documentation was drafted with AI assistance and reviewed by the
maintainer. This disclosure covers documentation only; see
`legal/DISCLAIMER.md`.*

Sponsor: <https://github.com/sponsors/poli0981>
