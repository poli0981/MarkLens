import 'dart:io';

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
  ///
  /// The last step of `ShutdownSequence`, and the only one that is not
  /// bounded: it is the exit.
  Future<void> detachAndClose(WindowListener listener);

  /// Brings the window forward, for a second launch handing paths over.
  Future<void> focus();

  /// Enters or leaves full screen.
  ///
  /// The shell hides its own chrome for `F11` either way; without this the
  /// window stayed exactly the size it was and only lost its menu bar, which
  /// is not what `docs/06_UI_UX.md` promises.
  Future<void> setFullScreen({required bool full});

  /// Asks the window to close, as File → Exit and the title-bar button do.
  ///
  /// Deliberately not [detachAndClose]: closing is intercepted
  /// (`setPreventClose`), so this comes back as `onWindowClose` and leaves by
  /// the one shutdown path that writes the session and releases the lock.
  Future<void> requestClose();
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

  /// Detaches, hides, and closes — in that order, and not `destroy()`.
  ///
  /// `destroy()` on Windows is `PostQuitMessage` and nothing else: the runner's
  /// message loop ends, and the Flutter engine is torn down in the window
  /// object's destructor, with the window still on screen and `OnDestroy` —
  /// the template's one guard around that teardown — never reached. That was
  /// the five-second close of v1.0.0 (`docs/03_DATA_FLOW.md`, "App exit"; the
  /// runner's destructor now carries the same guard). `close()` takes the
  /// stock path instead: `WM_CLOSE` → `DestroyWindow`, which removes the
  /// window from the screen and then tears the engine down from `WM_DESTROY`,
  /// inside the loop, through `OnDestroy`. On Linux the plugin's `destroy()`
  /// and `close()` are the same `gtk_window_close`, so nothing changes there.
  ///
  /// The hide first is insurance: the window is gone at once, whatever the
  /// process spends after. Windows only — `gtk_window_close` on a hidden
  /// toplevel is a corner nobody has measured, and Linux has nothing to hide
  /// from.
  ///
  /// The listener goes first because `WM_CLOSE` re-emits `close` over the
  /// channel, and with `setPreventClose(false)` that must not come back as a
  /// second `onWindowClose`.
  @override
  Future<void> detachAndClose(WindowListener listener) async {
    windowManager.removeListener(listener);
    if (Platform.isWindows) {
      await windowManager.hide();
    }
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> setFullScreen({required bool full}) async {
    try {
      await windowManager.setFullScreen(full);
    } on Object {
      // A compositor that refuses full screen is not a reason to take the app
      // down (CLAUDE.md rule 9); the chrome still collapses either way.
    }
  }

  @override
  Future<void> requestClose() => windowManager.close();
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

  @override
  Future<void> setFullScreen({required bool full}) async {}

  @override
  Future<void> requestClose() async {}
}
