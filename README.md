# MarkLens

**Project:** MarkLens — a fast, lightweight, read-only Markdown viewer
**Repo:** `poli0981/MarkLens`
**Platforms:** Windows 10+ · Ubuntu 22.04+ (Linux desktop)
**Stack:** Flutter 3.47.1 stable / Dart 3.13.1 · **License:** GPL-3.0-only
**Suite version:** 1.0 · **Date:** 2026-08-30
**Status:** **v1.0.0 released** (2026-08-30) — M0–M4 closed. Verified on Ubuntu 26.04.1, Windows 10 and a Windows 11 Sandbox. One release-checklist item is carried to v1.0.1 rather than ticked: the manual ProcMon/`strace` read-only pass (`docs/15_SPIKES_ROADMAP.md`).

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

## Install

Downloads are on the [releases page](https://github.com/poli0981/MarkLens/releases).

| File | For |
|---|---|
| `MarkLens-Setup-x.y.z.exe` | Windows. Per-user, no administrator rights, registers `.md` |
| `MarkLens-x.y.z-win-x64-portable.zip` | Windows, unzip and run. No registration |
| `marklens_x.y.z_amd64.deb` | Debian/Ubuntu. The integrated Linux path |
| `MarkLens-x.y.z-x86_64.AppImage` | Any Linux. One file, `chmod +x` and run |

Every release ships `SHA256SUMS`. Download it beside the file you want and:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

**Windows needs the Microsoft Visual C++ Redistributable (x64).** Flutter links
against the MSVC runtime and does not bundle it, so on a Windows without it —
a fresh install, a VM, a Sandbox — MarkLens will not start, and the message says
`VCRUNTIME140_1.dll` or `MSVCP140.dll` rather than anything useful. Almost every
real machine already has it; get it from
<https://aka.ms/vs/17/release/vc_redist.x64.exe> if yours does not. The
installer checks and tells you; the portable zip cannot, so this paragraph is
where that ends up. **This applies to the portable zip too.**

Two more things about the Windows installer that are worth knowing before they
surprise you, because neither is something an installer can fix:

- **SmartScreen will warn on the download.** The installer is not code-signed;
  a certificate is a cost and a process that a v1 of a free viewer has not
  taken on. The checksum above is the verification that is actually available.
- **Windows may still ask "How do you want to open this?" the first time.** The
  installer registers MarkLens as a handler, but the *default* handler is
  recorded with a hash Windows reserves for a choice you make yourself. Pick
  MarkLens once and it sticks.

Config lives in `%APPDATA%\poli0981\MarkLens\marklens\` on Windows and
`$XDG_DATA_HOME/dev.poli0981.marklens/marklens/` on Linux — two small JSON
files, and the only thing MarkLens ever writes. Uninstalling leaves them; the
Windows uninstaller offers to remove them, unchecked.

## Build quickstart

```bash
flutter --version        # 3.47.1 stable — exact pin in docs/01_TECH_STACK.md
flutter pub get
flutter analyze && dart format --set-exit-if-changed .
flutter test
flutter build windows    # or: flutter build linux
```

Packaging is documented in `docs/11_PACKAGING_UPDATE.md` and lives in
`packaging/`: an Inno Setup script and a PowerShell driver for Windows, and
`build-deb.sh` / `build-appimage.sh` for Linux. The Linux artefacts are built
inside the `tool/linux` container — an `ubuntu:22.04` image, because the glibc
a binary links against is the glibc of the machine that built it and 22.04 is
the platform floor. `tool/linux/README.md` has the commands.

`tool/` also holds the two generators whose output is committed: the icon set
(`tool/icons/`) and the subset fonts (`tool/fonts/`). Edit the script, not the
output.

## File associations

The Windows installer registers `MarkLens.Document` for `.md` (checked) and
`.mdx` (unchecked — MDX usually belongs to an editor), per-user, no admin
rights. The `.deb` installs a `.desktop` entry and its MIME definitions.

**AppImage is the exception**, and it is a property of AppImage rather than of
MarkLens: an AppImage is a single file that the desktop does not know about
until something tells it, so file associations need your own integration
tooling (`appimaged`, Gear Lever, or a hand-written `.desktop`). If you want
double-click-to-open on Linux, the `.deb` is the integrated path.

Either way, double-clicking a second file while MarkLens is running opens it in
the window that is already there rather than starting a second one.

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
| `docs/14_CI_CD.md` | CI jobs, the release pipeline, pinning non-negotiables |
| `docs/15_SPIKES_ROADMAP.md` | P0 spikes S1–S5, milestones M0–M4, release checklist |
| `legal/` | PRIVACY, EULA, DISCLAIMER, THIRD_PARTY_NOTICES, licence texts |
| `packaging/` | What the installers reference, and the scripts that build them |
| `tool/` | Generators and containers: icons, fonts, goldens, Linux artefacts |

## License

GPL-3.0-only. Full license text is in `LICENSE` at the repo root.

---

*Repository documentation was drafted with AI assistance and reviewed by the
maintainer. This disclosure covers documentation only; see
`legal/DISCLAIMER.md`.*

Sponsor: <https://github.com/sponsors/poli0981>
