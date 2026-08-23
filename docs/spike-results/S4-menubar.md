# S4 — Menu bar & shortcuts prototype

**Status:** complete — the "feels right" gate was accepted as-is
**Branch:** `spike/s4-menubar`
**Machine:** Windows 11, Flutter 3.47.1 / Dart 3.13.1
**Date:** 2026-08-23

Doc 15 asks for a menu bar skeleton with five real items and the doc 06
shortcut set, passing on full keyboard traversal, no conflicts with Flutter's
defaults, and a subjective judgement.

## Result 1 — doc 06's premise was half right

Doc 06 says: *"`PlatformMenuBar` is macOS-only, so the bar is our own widget
row."* The conclusion is right — `PlatformMenuBar` hands the menu to the
platform and is not what we want. But the reasoning skipped a step: Flutter
also ships **`MenuBar` / `SubmenuButton` / `MenuItemButton`** in Material,
which already *are* "our own widget row" — plain widgets, themed through
`MenuBarTheme`, identical on Windows and Linux.

Using them rather than hand-rolling gets, for free:

- arrow-key traversal and `Esc` dismissal (`_kMenuTraversalShortcuts`),
- shortcut labels rendered beside each item from the activator itself,
- `CheckboxMenuButton` and `RadioMenuButton` for the View menu's toggles,
- accelerator support (below).

## Result 2 — "Alt focuses the menu bar" is not achievable

`_MenuBarAnchorState` wraps the bar in `ExcludeFocus(excluding: !isOpen)`. While
every menu is closed, the whole bar is out of the focus tree — measured
directly: the File button's `canRequestFocus` is `false`, so `requestFocus()`
is a silent no-op.

So Windows' highlight-the-bar-without-opening-it state cannot be reproduced
without abandoning `MenuBar` entirely. **Alt opens the File menu instead**,
which is one keystroke rather than Windows' Alt-then-Down, and Alt again closes
it and returns focus to the reader.

Two related findings:

- **A bare `Alt` cannot be a `Shortcuts` entry at all.** `SingleActivator`
  asserts its trigger is not a modifier key. Alt is handled on raw key events
  in the shell instead, tracking press-then-release with nothing in between —
  which is also what leaves `Alt+F4` and friends untouched.
- **`MenuAcceleratorLabel` gives the real Windows convention.** Labels written
  `&File` underline the letter while Alt is held and answer `Alt+F`. The marker
  has to live in the *translated* string, since the letter differs per
  language: `&File` / `&Tệp` / `ファイル(&F)`. A test asserts the three letters
  are distinct **within each locale** — two menus answering the same `Alt+key`
  is the kind of bug you otherwise find by accident.

## Result 3 — no shortcut conflicts on Windows or Linux

Flutter's `DefaultTextEditingShortcuts` binds **no** `Control`+letter
combinations on Windows or Linux. It binds `Control` + A/B/E/F/N/T on **macOS**
— the emacs caret bindings — which would swallow `Ctrl+B` (sidebar) and
`Ctrl+F` (find). macOS is a charter non-goal for v1; if it is ever revisited,
that collision is the first thing to resolve, and it is recorded in
`lib/app/shortcuts.dart` where someone will actually see it.

The test is behavioural rather than a copy of Flutter's tables: every activator
in the inventory is fired **while a `TextField` holds focus**, and must still
reach its action. Flutter's own maps are private and would drift; this cannot.

## What was built

| | |
|---|---|
| `lib/app/shortcuts.dart` | The whole doc 06 inventory as one map, used both to bind the shortcuts and to label the menu items — so the menu cannot advertise a combination nobody wired |
| `lib/app/menu/app_menu_bar.dart` | File · View · Help, every label through ARB |
| `lib/app/chrome.dart` | Sidebar, outline, zoom, theme and full-screen state |
| `lib/app/app.dart` | Shortcut/action wiring, the bare-Alt handler, and a shell that visibly reflects the chrome |

**The View menu is fully live** — sidebar, outline, zoom (clamped 50–300%),
theme, full screen — because all of it is local UI state, so the subjective
gate can actually be exercised rather than imagined. File and Help items that
need file I/O or the update service are bound and announce themselves as not
yet wired. Help → Third-party Licenses and About are live.

Tests: 24 in `test/app/shortcuts_test.dart`, 13 in `test/app/menu_bar_test.dart`
— including that the bar renders in Vietnamese and Japanese with no English
leaking through.

## Doc 06 amendments

- Shortcut table: `Alt` no longer "focuses the menu bar"; it **opens the File
  menu**, and `Alt+F` / `Alt+V` / `Alt+H` open a menu directly.
- The note about building our own widget row is replaced with what we actually
  did and why.

## The subjective gate — passed

Doc 15 makes this the maintainer's call, and it is the one thing a test cannot
answer. The prototype was run on Windows 11 and accepted without changes, so
the behaviour described above is what M1 builds on: `Alt` opens the File menu,
accelerators on the three titles, and Flutter's `MenuBar` underneath.

One alternative was raised and declined: dropping the bare-`Alt` behaviour
entirely and keeping only `Alt+F` / `Alt+V` / `Alt+H`. That would be less
surprising for anyone expecting Windows' highlight-only state, at the cost of a
keyboard entry point. Recorded in case it comes back.

To re-run it:

```bash
flutter run -d windows
```

Worth trying: tap `Alt` on its own; `Alt+V` then arrows; `Esc` from a submenu;
`Ctrl+B` / `Ctrl+U` / `Ctrl+=` / `Ctrl+0` / `F11`; and the Theme submenu with
the window in each mode. The status bar along the bottom reports the chrome
state so the shortcuts are visibly doing something.
