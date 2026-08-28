import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';

/// Files dropped onto the window (`docs/03_DATA_FLOW.md`, "Open").
///
/// A seam over `desktop_drop` for the reasons every platform seam here exists:
/// the plugin has no channel in a widget test, and `app/open_files.dart` and
/// `app/save_file.dart` are the only other places that touch a picker.
///
/// `desktop_drop` has been a pinned dependency imported nowhere since M0. Doc
/// 03 lists drag-and-drop as one of the four ways a document arrives — beside
/// the dialog, the command line and a forwarded second launch — and it was the
/// only one of the four that did not work.
abstract class DropTargetLink {
  /// Wraps [child] so dropping files on it calls [onDrop] with their paths.
  Widget wrap({
    required Widget child,
    required ValueChanged<List<String>> onDrop,
    required ValueChanged<bool> onHover,
  });
}

/// The real drop target.
class PlatformDropTargetLink implements DropTargetLink {
  /// Creates a drop target.
  const PlatformDropTargetLink();

  @override
  Widget wrap({
    required Widget child,
    required ValueChanged<List<String>> onDrop,
    required ValueChanged<bool> onHover,
  }) => DropTarget(
    onDragEntered: (_) => onHover(true),
    onDragExited: (_) => onHover(false),
    onDragDone: (details) {
      onHover(false);
      onDrop(<String>[for (final file in details.files) file.path]);
    },
    child: child,
  );
}

/// What a widget test gets: the child, unwrapped.
///
/// Tests drive `OpenSetController.openPaths` directly, which is what a drop
/// resolves to — there is nothing between the two but the plugin.
class NoDropTargetLink implements DropTargetLink {
  /// Creates an inert drop target.
  const NoDropTargetLink();

  @override
  Widget wrap({
    required Widget child,
    required ValueChanged<List<String>> onDrop,
    required ValueChanged<bool> onHover,
  }) => child;
}
