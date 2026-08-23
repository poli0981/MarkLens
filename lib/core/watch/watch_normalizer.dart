import 'dart:async';

import 'package:marklens/core/models/watch_event.dart';

/// Turns the raw event stream from a filesystem watcher into the two events
/// MarkLens actually cares about: a document **changed**, or a document has
/// gone **missing** (`docs/03_DATA_FLOW.md`, `docs/07_FILES_AND_WATCH.md`).
///
/// Pure Dart — it never touches the filesystem itself. Whether a path still
/// exists is asked of [pathExists], which the caller supplies. That is what
/// keeps this unit-testable without a disk and what lets the tests replay
/// event sequences captured from real editors.
///
/// **The classification rule, from spike S5:** when the debounce window for a
/// path closes, look at whether the path *exists*. Never at the event types.
/// The observed sequences on Windows/NTFS make the reason plain:
///
/// ```text
/// write in place        modify                        -> changed
/// temp + rename over    modify                        -> changed
/// delete + recreate     remove, add   (7 ms, 28 ms)   -> changed
/// vim rename + write    remove, add   (8 ms, 29 ms)   -> changed
/// five rapid writes     modify x5     (6..135 ms)     -> changed, once
/// real deletion         remove        (7 ms)          -> missing
/// ```
///
/// The first event of "delete + recreate" is byte-for-byte the same as the
/// first event of a real deletion. Only time tells them apart, so nothing is
/// classified until the window closes.
class WatchNormalizer {
  /// Creates a normalizer.
  ///
  /// [pathExists] is asked once per path when its window closes.
  WatchNormalizer({
    required this.pathExists,
    this.debounce = const Duration(milliseconds: 200),
  });

  /// How long a path's events are collected before it is classified.
  ///
  /// 200 ms per `docs/07_FILES_AND_WATCH.md`. S5 measured the widest gap
  /// inside a single save at 29 ms, so this has an order of magnitude of
  /// headroom — the cost of raising it is only how late a reload feels.
  final Duration debounce;

  /// Whether the given path exists right now.
  final bool Function(String path) pathExists;

  final Map<String, Timer> _pending = <String, Timer>{};
  final StreamController<WatchEvent> _out =
      StreamController<WatchEvent>.broadcast();

  /// Normalized events, one per path per settled burst.
  Stream<WatchEvent> get events => _out.stream;

  /// Feeds one raw event in.
  ///
  /// The event's *kind* is deliberately ignored; only its path matters. Every
  /// raw event for a path simply restarts that path's window.
  void add(String path) {
    _pending[path]?.cancel();
    _pending[path] = Timer(debounce, () => _settle(path));
  }

  void _settle(String path) {
    _pending.remove(path);
    if (_out.isClosed) return;
    _out.add(
      WatchEvent(
        path: path,
        kind: pathExists(path)
            ? WatchEventKind.changed
            : WatchEventKind.missing,
      ),
    );
  }

  /// Classifies everything still in flight immediately.
  ///
  /// Used by the window-focus sweep (`docs/03_DATA_FLOW.md`), which should not
  /// have to wait out a debounce window that started before the user came
  /// back to the app.
  void flush() {
    for (final path in _pending.keys.toList()) {
      _pending.remove(path)?.cancel();
      _settle(path);
    }
  }

  /// Whether any path is still inside its debounce window.
  bool get hasPending => _pending.isNotEmpty;

  /// Cancels every pending window and closes [events].
  Future<void> dispose() async {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    await _out.close();
  }
}
