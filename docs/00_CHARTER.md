# 00 · Charter

## Product statement

MarkLens is to Markdown what SumatraPDF is to PDF: a small, fast, read-only
viewer that opens instantly, renders faithfully, remembers where you were,
and never touches your files. People currently *view* Markdown in tools built
for *editing* (VS Code, Obsidian, Typora). MarkLens serves the moments when
you only want to read: browsing a repo's docs folder, reading a README from
Explorer, keeping rendered notes open next to an editor.

## Target user

Developers and writers on Windows/Ubuntu with folders full of `.md`/`.mdx`
files. Primary persona: the maintainer's own daily workflow — docs folders of
active projects open all day beside an editor, auto-reloading on save.

## Principles (in priority order)

1. **Faithful rendering.** The document looks right — GFM tables, task lists,
   code highlighting, images — and looks *the same* on both OSes.
2. **Instant.** Cold start to restored session feels immediate; opening a file
   never shows a spinner for ordinary documents.
3. **Boring reliability.** No file ever crashes the app; worst case is a
   plain-text fallback with a notice.
4. **Respectful.** Read-only, offline by default, no telemetry, GPL-3.0.
5. **Small.** In download size, in RAM, in UI surface. Features must earn
   their place.

## v1 scope

Open files/folder (≤1,000 entries) · session restore · sidebar + tabs +
quick switcher · GFM rendering + highlight + SVG · MDX as inert placeholders ·
front-matter panel · outline/TOC · find in file + across open files ·
watch/auto-reload · zoom + themes · relative-link navigation · file
association + CLI + single instance · EN/VI/JA · Windows & Ubuntu packages.

## Non-goals for v1

Editing of any kind (including "quick fixes") · export to HTML/PDF · sync,
cloud, accounts · plugin system · WYSIWYG or split view · tabs across
multiple windows · macOS (revisit post-1.0) · mermaid/KaTeX rendering
(displayed as code blocks; webview-free math is a possible v1.x
investigation) · wiki-links `[[...]]` (v1.x candidate).

## Success criteria (measured on the reference dev machine and a clean
Ubuntu 24.04 VM)

- Cold start → previous session visible: **< 1.5 s**.
- Open + render a typical 100 KB document: **< 150 ms** to first paint.
- 1 MB torture document scrolls at **≥ 55 fps** average.
- RAM steady-state with 1,000 entries open (metadata) + 40 cached **parsed**
  docs: **< 400 MB**. (Parsed, not rendered: the cache holds `DocModel`s and
  never widgets — rule 8.)
- Zero writes outside the app config directory (verified by test + manual
  procmon/strace pass before each release).

## Platform floor

Windows 10 x64 and Ubuntu 22.04 amd64 (GTK 3 present). Reference targets:
Windows 11 and Ubuntu 24.04.
