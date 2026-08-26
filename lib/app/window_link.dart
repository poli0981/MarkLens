import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:window_manager/window_manager.dart';

/// Where the window is, as the session will remember it.
///
/// Plain state rather than a live query, because the session save runs on a
/// debounce and must not block on the platform to find out where the window
/// was a second ago.
class WindowGeometryController extends Notifier<WindowGeometry?> {
  @override
  WindowGeometry? build() => null;

  /// The last recorded position and size, or `null` before the first one.
  WindowGeometry? get geometry => state;

  /// Records a new position or size.
  set geometry(WindowGeometry? value) => state = value;
}

/// The window geometry provider.
final NotifierProvider<WindowGeometryController, WindowGeometry?>
windowGeometryProvider =
    NotifierProvider<WindowGeometryController, WindowGeometry?>(
      WindowGeometryController.new,
    );

/// Everything MarkLens asks of the real window.
///
/// A seam, for the same reason `FilePickerPrompt` is one: `window_manager` is
/// a plugin, and a widget test has no platform channel behind it. Calling it
/// there does not merely fail — some calls return a future that never
/// completes, which hangs `pumpAndSettle` rather than throwing something a
/// `try` could catch. Tests substitute [NoWindowLink] and the shell does not
/// notice.
abstract class WindowLink {
  /// Prepares the window before it is shown.
  Future<void> prepare();

  /// Puts back a remembered geometry.
  Future<void> restore(WindowGeometry? geometry);

  /// The window's current geometry, or `null` if it cannot be had.
  Future<WindowGeometry?> current();

  /// Starts routing window events to [listener], and takes over closing so the
  /// session can be written first.
  Future<void> attach(WindowListener listener);

  /// Stops routing events and lets the window go.
  Future<void> detachAndClose(WindowListener listener);

  /// Brings the window forward, for a second launch handing paths over.
  Future<void> focus();
}

/// The real window.
class PlatformWindowLink implements WindowLink {
  /// Creates a link to the platform window.
  const PlatformWindowLink();

  /// The doc 00 platform floor is a desktop, so a window smaller than this is
  /// a mistake rather than a preference.
  static const Size minimumSize = Size(640, 480);

  @override
  Future<void> prepare() async {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(minimumSize);
  }

  @override
  Future<void> restore(WindowGeometry? geometry) async {
    if (geometry == null) {
      return;
    }
    try {
      await windowManager.setBounds(
        Rect.fromLTWH(geometry.x, geometry.y, geometry.width, geometry.height),
      );
      if (geometry.maximized) {
        await windowManager.maximize();
      }
    } on Object {
      // A monitor that is no longer attached. Opening at the default size
      // beats not opening (CLAUDE.md rule 9).
    }
  }

  @override
  Future<WindowGeometry?> current() async {
    try {
      final bounds = await windowManager.getBounds();
      return WindowGeometry(
        x: bounds.left,
        y: bounds.top,
        width: bounds.width,
        height: bounds.height,
        maximized: await windowManager.isMaximized(),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> attach(WindowListener listener) async {
    windowManager.addListener(listener);
    // The session has to be written before the window goes, so closing is
    // intercepted and completed by `detachAndClose`.
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> detachAndClose(WindowListener listener) async {
    windowManager.removeListener(listener);
    await windowManager.destroy();
  }

  @override
  Future<void> focus() => windowManager.focus();
}

/// A window that is not there.
///
/// What a widget test gets. Every method succeeds immediately and does
/// nothing, so cold start runs to completion exactly as it would with a real
/// window minus the geometry.
class NoWindowLink implements WindowLink {
  /// Creates a no-op link.
  const NoWindowLink();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> restore(WindowGeometry? geometry) async {}

  @override
  Future<WindowGeometry?> current() async => null;

  @override
  Future<void> attach(WindowListener listener) async {}

  @override
  Future<void> detachAndClose(WindowListener listener) async {}

  @override
  Future<void> focus() async {}
}
