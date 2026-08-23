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
  Open Recent ▸ · Reload `Ctrl+R` · Copy entire document `Ctrl+Shift+C` ·
  Close Tab `Ctrl+W` · Close All · Settings… `Ctrl+,` · Exit
- **View** — Toggle Sidebar `Ctrl+B` · Toggle Outline `Ctrl+U` ·
  Zoom In/Out/Reset `Ctrl+= / Ctrl+- / Ctrl+0` · Theme ▸ System/Light/Dark ·
  Full Screen `F11`
- **Help** — Check for Updates… · Third-party Licenses ·
  Export Diagnostic Log… · About MarkLens

`PlatformMenuBar` hands the menu to the platform and is not what we want, so
the bar is a widget row styled to the app theme and identical on both OSes.
Built on Flutter's Material `MenuBar`, which already is that row and brings
arrow traversal, `Esc` dismissal and shortcut labels with it (spike S4).

**Keyboard:** `Alt` on its own **opens the File menu**, and `Alt` again closes
it and hands focus back to the reader. `Alt+F` / `Alt+V` / `Alt+H` open a menu
directly, with the accelerator letter underlined while `Alt` is held; that
letter is part of the *translated* label, because it has to differ per
language. Arrows move between and within menus, `Esc` closes.

S4 originally specified `Alt` as *focusing* the bar without opening it, the way
Windows does. Flutter's `MenuBar` excludes itself from the focus tree while
every menu is closed, so that state is unreachable without giving up `MenuBar`
entirely — measured in `docs/spike-results/S4-menubar.md`.

## Shortcuts (full inventory — no others in v1)

| Keys | Action |
|---|---|
| Ctrl+O / Ctrl+Shift+O | Open file(s) / folder |
| Ctrl+P | Quick switcher (fuzzy over open set + recent) |
| Ctrl+F / Ctrl+Shift+F | Find in file / across open files |
| Ctrl+R | Reload active file |
| Ctrl+Shift+C | Copy entire document (Markdown source) |
| Ctrl+W / Ctrl+Shift+T | Close tab / reopen closed tab |
| Ctrl+Tab / Ctrl+Shift+Tab | Next / previous tab (MRU order) |
| Ctrl+= · Ctrl+- · Ctrl+0 | Zoom in · out · reset (50–300%) |
| Ctrl+B / Ctrl+U | Toggle sidebar / outline |
| Ctrl+, | Settings |
| F11 / Esc | Full screen / leave, close bars |
| Alt | Open the File menu (again to close) |
| Alt+F · Alt+V · Alt+H | Open File · View · Help directly |

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

The reader is wrapped in `SelectionArea`, and cross-block select/copy is a
release gate (Spike S2 — passes). Selecting across a heading, paragraph, code
block and table cell yields clean text, with Vietnamese diacritics, Japanese
and code indentation intact. Dragging past the viewport edge auto-scrolls and
keeps extending the selection into blocks built during the drag.

**`Ctrl+A` reaches only what is rendered, and that is deliberate.** Blocks are
built lazily (doc 04), so a block that has not been built cannot be selected.
Building the whole document up front to make it selectable was measured and
rejected: 527 ms to first paint on a *typical* 100 KB document against a
150 ms budget, and outright process death at 1 MB
(`docs/spike-results/S2-selection.md`). Instead, **File → Copy entire document
(`Ctrl+Shift+C`)** copies `DocModel.sanitizedSource` straight from the model —
exact by construction, and indifferent to what has been built. Note it copies
the **Markdown source**, which differs deliberately from the rendered text a
drag-selection produces.

Code blocks: language label + copy button + hover
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
