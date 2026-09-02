import 'dart:async';

import 'package:marklens/app/watch_link.dart';
import 'package:marklens/app/window_link.dart';
import 'package:marklens/core/log/log_buffer.dart';
import 'package:marklens/core/single_instance.dart';
import 'package:window_manager/window_manager.dart';

/// The one way out (`docs/03_DATA_FLOW.md`, "App exit").
///
/// Until v1.0.1 the shell wrote the session, released the lock and asked the
/// window to go, and that was the whole of it. Two things were missing, and
/// both came from the same fact: **the `ProviderScope` is never disposed on a
/// real exit.** The process ends with the window, so every `ref.onDispose`
/// hook — the settings flush, the watcher teardown — was registered and never
/// ran. A setting changed in its 250 ms coalescing window was lost, and on
/// Windows each watched root's isolate was left for the VM to tear down.
///
/// (The five-second close that prompted all this was neither of those. It was
/// the native runner's destructor tearing the engine down with its pointer
/// still set — doc 03, "App exit" — and it was found by measuring, after the
/// two leaks above had been fixed and the close was still slow.)
///
/// So the sequence is explicit, in this order, and each rule is load-bearing:
///
/// 1. **Write first.** Geometry, settings, session — all on disk before
///    anything is asked to stop. From here on a bound that fires skips a
///    *wait*, never data.
/// 2. **Ask before leaving.** The watchers are told to close and the answer is
///    awaited, because the ask has to actually be dispatched before the engine
///    goes — an isolate nobody asked is left for the VM.
/// 3. **Every wait is bounded.** Per step rather than one overall timer, so
///    the log names the step that did not answer.
/// 4. **Once.** A second close — a double-click on the button, `Alt+F4` while
///    the first is running, File → Exit after either — joins the run already
///    in progress rather than starting a rival.
///
/// Collaborators are captured up front rather than read from a `Ref`, for the
/// same reason `AppSettingsController.flush` keeps its store: nothing here may
/// depend on the scope after an `await`.
class ShutdownSequence {
  /// Creates a sequence over the given collaborators.
  ShutdownSequence({
    required this.recordGeometry,
    required this.flushSettings,
    required this.flushSession,
    required this.stopListening,
    required this.watch,
    required this.instance,
    required this.window,
    required this.listener,
    required this.log,
    this.geometryTimeout = const Duration(milliseconds: 500),
    this.watchTimeout = const Duration(seconds: 1),
    this.instanceTimeout = const Duration(seconds: 1),
  });

  /// The `source` every entry this writes to [log] carries.
  static const String logSource = 'shutdown';

  /// Asks the window where it is and records the answer for the session.
  final Future<void> Function() recordGeometry;

  /// Writes any settings change still inside its coalescing window.
  final void Function() flushSettings;

  /// Records the session as it is now and writes it.
  final void Function() flushSession;

  /// Stops the shell listening to things that are about to go away — the
  /// forwarded-paths stream and the watch coordinator's events.
  final void Function() stopListening;

  /// The watchers, which are asked to close and given [watchTimeout].
  final WatchLink watch;

  /// The single-instance lock, released within [instanceTimeout].
  final SingleInstance instance;

  /// The window, which goes last.
  final WindowLink window;

  /// The shell's listener, detached so the close it triggers does not come
  /// back as another `onWindowClose`.
  final WindowListener listener;

  /// Where a bound that fires, or a step that fails, is recorded.
  final LogBuffer log;

  /// How long the geometry query may take.
  final Duration geometryTimeout;

  /// How long the watchers may take to confirm they have stopped.
  final Duration watchTimeout;

  /// How long releasing the lock may take.
  final Duration instanceTimeout;

  Future<void>? _run;

  /// Whether [run] has been called.
  bool get started => _run != null;

  /// Runs the sequence, or joins the run already in progress.
  Future<void> run() => _run ??= _runOnce();

  Future<void> _runOnce() async {
    await _bounded('window geometry', recordGeometry, geometryTimeout);
    _sync('settings', flushSettings);
    _sync('session', flushSession);
    _sync('listeners', stopListening);
    await _bounded('watchers', watch.dispose, watchTimeout);
    // A watcher that has only *scheduled* its close needs one more turn of the
    // event loop for the message to leave. Cheap, and it is the difference
    // between asking and merely meaning to.
    await Future<void>.delayed(Duration.zero);
    await _bounded('single instance', instance.release, instanceTimeout);
    // Not bounded: this is the exit itself, and there is nothing after it to
    // continue to.
    try {
      await window.detachAndClose(listener);
    } on Object catch (error) {
      log.error(logSource, 'closing the window failed: $error');
    }
  }

  Future<void> _bounded(
    String step,
    Future<void> Function() action,
    Duration bound,
  ) async {
    try {
      await action().timeout(
        bound,
        onTimeout: () => log.warn(
          logSource,
          '$step did not finish within ${bound.inMilliseconds} ms; continuing',
        ),
      );
    } on Object catch (error) {
      log.warn(logSource, '$step failed: $error; continuing');
    }
  }

  void _sync(String step, void Function() action) {
    try {
      action();
    } on Object catch (error) {
      log.warn(logSource, '$step failed: $error; continuing');
    }
  }
}
