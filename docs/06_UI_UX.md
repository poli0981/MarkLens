# 06 · UI / UX

## Layout

```
┌───────────────────────────────────────────────────────┐
│ Menu bar   File · View · Help                         │
├───────────────────────────────────────────────────────┤
│ Tab strip  [README.md] [ARCH.md] [• changed] … (⌃P)   │
├──────────┬────────────────────────────────┬───────────┤
│ Sidebar  │            Reader              │  Outline  │
│ (tree /  │   centered column,             │  (TOC)    │
│  list)   │   max-width, SelectionArea     │           │
├──────────┴────────────────────────────────┴───────────┤
│ Status bar  path · position % · word count · notices  │
└───────────────────────────────────────────────────────┘
```

Sidebar and outline are collapsible; widths persist in session. The reader
column centers at `reading.contentMaxWidth` for comfortable line length.

## Menu map

- **File** — Open File(s)… `Ctrl+O` · Open Folder… `Ctrl+Shift+O` ·
  Open Recent ▸ · Reload `Ctrl+R` · Close Tab `Ctrl+W` · Close All ·
  Settings… `Ctrl+,` · Exit
- **View** — Toggle Sidebar `Ctrl+B` · Toggle Outline `Ctrl+U` ·
  Zoom In/Out/Reset `Ctrl+= / Ctrl+- / Ctrl+0` · Theme ▸ System/Light/Dark ·
  Full Screen `F11`
- **Help** — Check for Updates… · Third-party Licenses ·
  Export Diagnostic Log… · About MarkLens

`PlatformMenuBar` is macOS-only, so the bar is our own widget row — styled
to the app theme, fully keyboard-navigable (`Alt` focuses it, arrows move,
`Esc` closes). That's consistent with a custom-styled app and identical on
both OSes.

## Shortcuts (full inventory — no others in v1)

| Keys | Action |
|---|---|
| Ctrl+O / Ctrl+Shift+O | Open file(s) / folder |
| Ctrl+P | Quick switcher (fuzzy over open set + recent) |
| Ctrl+F / Ctrl+Shift+F | Find in file / across open files |
| Ctrl+R | Reload active file |
| Ctrl+W / Ctrl+Shift+T | Close tab / reopen closed tab |
| Ctrl+Tab / Ctrl+Shift+Tab | Next / previous tab (MRU order) |
| Ctrl+= · Ctrl+- · Ctrl+0 | Zoom in · out · reset (50–300%) |
| Ctrl+B / Ctrl+U | Toggle sidebar / outline |
| Ctrl+, | Settings |
| F11 / Esc | Full screen / leave, close bars |
| Alt | Focus menu bar |

## Sidebar

Two presentations: **flat list** for ad-hoc files, **tree** per open root.
Virtualized (`ListView.builder`) — 1,000 entries must scroll cold without
jank. Rows: name, subtle relative path, badges (`missing`, `pinned`,
`stale`). Context menu: Reveal in file manager · Pin · Close. Natural sort
(`2.md` before `10.md`).

## Tabs

Scrollable strip; pinned tabs stick left; overflow relies on Ctrl+P rather
than a chevron menu (v1 simplicity). Dot indicator = changed-on-disk while
inactive. Middle-click closes.

## Reader

Whole document wrapped in `SelectionArea` — cross-block select/copy is a
release gate (Spike S2). Code blocks: language label + copy button + hover
scrollbar for long lines. Task-list checkboxes render but are inert
(read-only tooltip on click). Front-matter panel per doc 04. Smooth
programmatic scrolls (outline/anchor jumps) with a brief highlight pulse on
the target heading.

## Outline

Heading tree, indent by level, current section highlighted on scroll
(scroll-spy), click to jump. Collapses to nothing gracefully for
heading-less docs.

## Empty & edge states

First-run empty state: drop hint + Open buttons + recent list. Drag-over
overlay. Cap-exceeded dialog (Open first N / Cancel). Missing-file tab body:
explanation + "Remove from session" + "Reveal parent folder".

## Theming

Tokens (finalize at M1, keep the set small): `bg`, `bgAlt`, `fg`, `fgMuted`,
`accent`, `codeBg`, `border`, `selection`. Light/dark/system via
`ThemeData`; highlight theme pairs switch with mode. Design intent:
quiet, typographic, reader-first — the accent appears in links, focus rings,
and the pulse highlight only.

## Accessibility

Everything reachable by keyboard (menu, sidebar, tabs, reader focus,
panels); visible focus indicators; AA contrast in both themes; UI honors
`fontScale`; screen-reader labels on icon-only buttons. A11y pass is part of
the feature DoD (doc 12).
