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

Sidebar and outline are collapsible. **The sidebar's width persists in the
session; the outline's does not** — `session.json` v1 has `sidebarWidth` and no
`outlineWidth` (doc 05), so the outline is fixed-width in v1. Corrected at M2
rather than adding the field: a second width would need a schema bump and a
migration fixture for no behaviour anyone asked for. The reader column centers
at `reading.contentMaxWidth` for comfortable line length.

## Status bar

`path · position % · word count · notices`, left to right, `·`-separated.
Written down properly at M2, because until then this line was still the S4
prototype's debug output (`zoom … · sidebar … · outline … · theme …`) — the
one place in the shell that shipped hardcoded English.

- **path** is `OpenedFile.path`, the display path in its on-disk casing —
  never `identity`, which is case-folded and would lower-case the folder names
  the user chose (doc 07). It takes whatever width the other three leave,
  ellipsises, and carries the full path as a tooltip (doc 09).
- **position %** is the reader's scroll offset over its extent. A document
  shorter than the window reads 0%. It is reported only when the whole percent
  changes, so scrolling does not rebuild the bar sixty times a second (rule 7).
- **word count** is over `sanitizedSource`, so front matter is not counted —
  it is metadata, not prose — and **fenced code is not counted either**,
  including the rescued raw-HTML blocks, which are fences by the time the
  reader sees them (doc 04). A reader asking how long a document is means the
  prose; a code sample would otherwise dominate the number.

  **Words are not whitespace-delimited runs.** Japanese is written without
  spaces, so splitting on whitespace reports a whole Japanese document as
  roughly one word, and doc 09 makes Japanese a first-class locale. Each CJK
  ideograph and kana counts as one word — the convention Japanese word
  processors use — while spaced scripts count runs. A run must contain a
  letter or digit to count, so a table rule or a thematic break is punctuation
  rather than prose. Vietnamese needs no special case: its combining marks are
  ordinary non-separator characters.
- **notices** is the count of `DocModel.notices`, and the field is **absent**
  at zero rather than reading "0 notices".

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

Two presentations, chosen by what is open rather than by a switch: a **flat
list** for files opened one at a time, and a **group per open root** for
folders. A file below a root shows its folder after the name; a loose file
shows its parent's name, so two `README.md` from different projects are
distinguishable at a glance. A file is claimed by exactly one root, so opening
a folder and then a folder inside it does not list anything twice.
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
(`Ctrl+Shift+C`)** copies `DocModel.rawSource` straight from the model — exact
by construction, and indifferent to what has been built. Note it copies the
**Markdown source**, which differs deliberately from the rendered text a
drag-selection produces.

`rawSource`, not `sanitizedSource`: the sanitized string is what the renderer
gets, with the front matter lifted out and block HTML rewritten, so copying it
would silently drop the user's front matter — the opposite of exact. `rawSource`
is the file as decoded, BOM stripped. A file that was not valid UTF-8 copies
with U+FFFD where the bad bytes were, which is what the reader is showing.

Code blocks: language label + copy button + hover
scrollbar for long lines; long lines scroll rather than wrap, because wrapping
code changes what it says. A block the raw-HTML rewrite produced (doc 04) uses
the same frame but opens **collapsed** and is titled "Raw HTML (not rendered)"
— the box itself is the signal that something was there, which is the failure
S1 found. A code block the author wrote is never collapsible: hiding content
behind a click is not a reader's job. Task-list checkboxes render but are
inert
(read-only tooltip on click). Front-matter panel per doc 04.

**Programmatic scrolls** (outline and anchor jumps) land on the block and mark
it with a brief accent pulse. "Smooth" needed a definition once it met a lazy
list, because a `ListView` cannot jump to an index it has never built and so
does not know the height of. A target that is already built animates to the top
over ~220 ms. One further away is converged on with invisible jumps — each jump
builds the children around it, which both answers the question and sharpens the
next estimate — and then glides the last stretch in. A single animation across
900,000 px of a 1 MB document would not be smooth, it would be a smear; what
the reader sees is a flash and then a settle, and the pulse is what says where
they landed.

## Outline

Heading tree, indent by level, current section highlighted on scroll
(scroll-spy), click to jump. Collapses to nothing gracefully for
heading-less docs.

## Empty & edge states

First-run empty state: drop hint + Open buttons + recent list — all three
built at M3; until then it was the drop hint alone. The two Open buttons are a
`Wrap`, not a `Row`: doc 09 asks for no fixed-width boxes around translated
text, and "Mở thư mục…" beside "Mở tệp…" overflows the width the English pair
only just fits. Drag-over overlay. Cap-exceeded dialog (Open first N / Cancel). Missing-file tab body:
explanation + "Remove from session" + "Reveal parent folder".

## Theming

**Finalized at M1** in `app/theme/reader_tokens.dart`: `bg`, `bgAlt`, `fg`,
`fgMuted`, `accent`, `codeBg`, `border`, `selection` — eight, light and dark.
Light/dark/system via `ThemeData`, carried as a `ThemeExtension` so every
widget reads them the same way. Design intent: quiet, typographic,
reader-first — the accent appears in links, focus rings, and the pulse
highlight only.

The set stays at eight, and a ninth needs an argument: a reading surface with
many colours is a reading surface that fights the document. The Material
`ColorScheme` is derived *from* these rather than beside them, so a Material
default cannot appear next to a token colour and look almost right.

**Contrast is asserted, not judged.** `test/app/reader_tokens_test.dart`
computes the WCAG ratios for every pairing that occurs on screen, in both
themes: AAA (7:1) for body text on the reading surface, AA (4.5:1) for
secondary text, links and selected text on every surface they land on, and a
band for borders so a hairline is neither invisible nor loud enough to read as
content. Change a colour and the test says whether it is still readable.

This also closes the S1 criterion that was waiting on the token set
(`docs/15_SPIKES_ROADMAP.md`): the renderer is driven entirely from these
through `ReaderStyle`, so it picks no colour of its own.

### Code colours

The highlighter's scope map is derived from the same eight (doc 01), which is
why `flutter_highlight` and its ninety bundled themes were dropped. Eight
tokens cannot make a rainbow, so the map earns its distinctions from weight and
slant instead: comments recede to `fgMuted` in italic, the things a reader
scans for take weight, and literals take `accent`. A scope that is not in the
map renders as body text, which keeps an unfamiliar grammar readable rather
than invisible.

## Notices

Required by CLAUDE.md rule 9, doc 00 principle 3, doc 02's error philosophy and
doc 04 stage 1 — and previously described by none of them. Decided at M1:

- **A slim bar directly above the document.** Not a line in the status bar:
  `plainTextFallback` means the reader is looking at something that is not the
  rendered document, and a person who misses that is being misled.
- **One notice at a time**, the most serious, with a count of the rest.
  Severity order: plain-text fallback, invalid UTF-8, MDX bail-out,
  unparsed front matter, large document. Stacking bars pushes the document
  down the screen, which is the thing the reader came for.
- **Dismissible**, by its close button, for that document only. Opening
  another document brings its own notices back — dismissing says "I have read
  this one", not "stop telling me about documents".
- Every kind's text is an ARB key, and the mapping is an exhaustive switch, so
  a new `DocNoticeKind` without a translation fails to compile rather than
  showing a blank bar.

## Accessibility

Everything reachable by keyboard (menu, sidebar, tabs, reader focus,
panels); visible focus indicators; AA contrast in both themes; screen-reader
labels on icon-only buttons. A11y pass is part of the feature DoD (doc 12).

**`reading.fontScale` scales the reading surface, not the window chrome.** This
line used to say the UI honours it generally, which is not buildable as
specified: the sidebar rows and the tab strip are fixed-height metrics
(`itemExtent`, a 34 px strip) that a 3× scale would burst rather than grow. The
document is what a reader zooms, and it is applied *clamped* — so Reset Zoom
means exactly 100% and the platform's own text scale is deliberately not
compounded on top of the user's choice.
