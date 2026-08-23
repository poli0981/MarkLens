/// The complete keyboard inventory from `docs/06_UI_UX.md`.
///
/// One map, used both to bind the shortcuts and to label the menu items, so a
/// menu can never advertise a key combination that is not wired — the two
/// cannot drift because there is only one of them.
///
/// **Conflicts with Flutter's own defaults** (spike S4, verified against
/// Flutter 3.47.1): none on Windows or Linux. Flutter binds no `Control` +
/// letter combinations in `DefaultTextEditingShortcuts` for either platform.
/// It *does* bind Control + A/B/E/F/N/T on macOS — the emacs-style caret
/// bindings — which would collide with `Ctrl+B` (sidebar) and `Ctrl+F` (find).
/// macOS is a charter non-goal for v1; if it is ever revisited, that collision
/// is the first thing to resolve. `test/app/shortcuts_test.dart` proves the
/// bindings still reach their actions even while a text field holds focus.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Open one or more documents.
class OpenFilesIntent extends Intent {
  /// Creates the intent.
  const OpenFilesIntent();
}

/// Open a folder of documents.
class OpenFolderIntent extends Intent {
  /// Creates the intent.
  const OpenFolderIntent();
}

/// Reload the active document from disk.
class ReloadDocumentIntent extends Intent {
  /// Creates the intent.
  const ReloadDocumentIntent();
}

/// Copy the whole document as Markdown source (`docs/06_UI_UX.md`).
class CopyDocumentIntent extends Intent {
  /// Creates the intent.
  const CopyDocumentIntent();
}

/// Close the active tab.
class CloseTabIntent extends Intent {
  /// Creates the intent.
  const CloseTabIntent();
}

/// Reopen the most recently closed tab.
class ReopenTabIntent extends Intent {
  /// Creates the intent.
  const ReopenTabIntent();
}

/// Move to the next or previous tab in most-recently-used order.
class CycleTabIntent extends Intent {
  /// Creates the intent.
  const CycleTabIntent({required this.forward});

  /// Whether to move forward through the MRU order.
  final bool forward;
}

/// Open the fuzzy quick switcher.
class QuickSwitcherIntent extends Intent {
  /// Creates the intent.
  const QuickSwitcherIntent();
}

/// Find within the active document.
class FindInFileIntent extends Intent {
  /// Creates the intent.
  const FindInFileIntent();
}

/// Search across all open files.
class FindAcrossFilesIntent extends Intent {
  /// Creates the intent.
  const FindAcrossFilesIntent();
}

/// Change the reading zoom level.
class ZoomIntent extends Intent {
  /// Zoom in one step.
  const ZoomIntent.zoomIn() : step = 1;

  /// Zoom out one step.
  const ZoomIntent.zoomOut() : step = -1;

  /// Return to 100%.
  const ZoomIntent.reset() : step = 0;

  /// `1` to zoom in, `-1` to zoom out, `0` to reset.
  final int step;
}

/// Show or hide the sidebar.
class ToggleSidebarIntent extends Intent {
  /// Creates the intent.
  const ToggleSidebarIntent();
}

/// Show or hide the outline panel.
class ToggleOutlineIntent extends Intent {
  /// Creates the intent.
  const ToggleOutlineIntent();
}

/// Enter or leave full screen.
class ToggleFullScreenIntent extends Intent {
  /// Creates the intent.
  const ToggleFullScreenIntent();
}

/// Open the settings screen.
class OpenSettingsIntent extends Intent {
  /// Creates the intent.
  const OpenSettingsIntent();
}

/// Move keyboard focus to the menu bar.
///
/// Flutter's `MenuBar` handles arrow traversal and `Esc` itself, but nothing
/// focuses the bar in the first place — that is a Windows convention Flutter
/// does not implement.
///
/// This intent is deliberately **not** in [appShortcuts]. `SingleActivator`
/// asserts that its trigger is not a modifier key, so a bare `Alt` cannot be
/// expressed as a shortcut at all (spike S4). It is raised from a key-event
/// handler in the shell instead, which watches for `Alt` pressed and released
/// with no other key in between — the Windows convention, and the only way to
/// tell "focus the menu" from "the user is typing Alt+F4".
class FocusMenuBarIntent extends Intent {
  /// Creates the intent.
  const FocusMenuBarIntent();
}

/// Every shortcut in `docs/06_UI_UX.md`, and no others.
///
/// `Alt` is absent for a different reason — see [FocusMenuBarIntent].
///
/// `Ctrl+A` is deliberately absent: it keeps its conventional meaning of
/// selecting the rendered text, and copying the *whole* document is
/// `Ctrl+Shift+C` instead — see `docs/spike-results/S2-selection.md`.
const Map<ShortcutActivator, Intent> appShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.keyO, control: true): OpenFilesIntent(),
  SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true):
      OpenFolderIntent(),
  SingleActivator(LogicalKeyboardKey.keyP, control: true):
      QuickSwitcherIntent(),
  SingleActivator(LogicalKeyboardKey.keyF, control: true): FindInFileIntent(),
  SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true):
      FindAcrossFilesIntent(),
  SingleActivator(LogicalKeyboardKey.keyR, control: true):
      ReloadDocumentIntent(),
  SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
      CopyDocumentIntent(),
  SingleActivator(LogicalKeyboardKey.keyW, control: true): CloseTabIntent(),
  SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true):
      ReopenTabIntent(),
  SingleActivator(LogicalKeyboardKey.tab, control: true): CycleTabIntent(
    forward: true,
  ),
  SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
      CycleTabIntent(forward: false),
  SingleActivator(LogicalKeyboardKey.equal, control: true): ZoomIntent.zoomIn(),
  SingleActivator(LogicalKeyboardKey.minus, control: true):
      ZoomIntent.zoomOut(),
  SingleActivator(LogicalKeyboardKey.digit0, control: true): ZoomIntent.reset(),
  SingleActivator(LogicalKeyboardKey.keyB, control: true):
      ToggleSidebarIntent(),
  SingleActivator(LogicalKeyboardKey.keyU, control: true):
      ToggleOutlineIntent(),
  SingleActivator(LogicalKeyboardKey.comma, control: true):
      OpenSettingsIntent(),
  SingleActivator(LogicalKeyboardKey.f11): ToggleFullScreenIntent(),
};
