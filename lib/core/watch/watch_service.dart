import 'dart:async';
import 'dart:io';

import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/watch/watch_normalizer.dart';
import 'package:watcher/watcher.dart' as w;

/// Starts the filesystem watchers and feeds them to a [WatchNormalizer]
/// (`docs/07_FILES_AND_WATCH.md`).
///
/// The normalizer has existed since M0 with nothing to feed it: `watcher` was a
/// production dependency imported only by a spike test, and no directory was
/// ever watched. This is the missing half.
///
/// Pure Dart — `watcher` is on the `core/` allowlist, and the only filesystem
/// question this asks is "does this path exist", which the normalizer needs to
/// classify.
class WatchService {
  /// Creates a service that watches nothing until [watch] is called.
  ///
  /// [openWatcher] is injected so a test can replay event sequences without a
  /// real filesystem or real time.
  WatchService({
    this.registry = ExtensionRegistry.standard,
    bool Function(String path)? pathExists,
    this.openWatcher = _openDirectoryWatcher,
    Duration debounce = const Duration(milliseconds: 200),
    this.disposeTimeout = const Duration(seconds: 1),
  }) : _normalizer = WatchNormalizer(
         pathExists: pathExists ?? _exists,
         debounce: debounce,
       );

  static w.DirectoryWatcher _openDirectoryWatcher(String path) =>
      w.DirectoryWatcher(path);

  static bool _exists(String path) => File(path).existsSync();

  /// Which files count. Events for anything else are dropped before the
  /// normalizer sees them.
  ///
  /// Not merely tidy: S5 measured Linux reporting the editor's own `note.md~`
  /// and `note.md.tmp` alongside the real save.
  final ExtensionRegistry registry;

  /// Opens a watcher on one directory. Injected so a test can replay events
  /// without a real filesystem or real time.
  final w.DirectoryWatcher Function(String path) openWatcher;

  /// How long [dispose] waits for the watchers to finish cancelling.
  ///
  /// A bound, not a budget: cancelling is asynchronous, and a watcher that
  /// never answers must not be able to hold the app open. Everything on disk
  /// was written before the watchers are asked to stop (`docs/03_DATA_FLOW.md`,
  /// "App exit"), so giving up on the wait loses nothing.
  final Duration disposeTimeout;
  final WatchNormalizer _normalizer;
  final Map<String, StreamSubscription<w.WatchEvent>> _watchers =
      <String, StreamSubscription<w.WatchEvent>>{};
  bool _degraded = false;
  bool _disposed = false;

  /// Normalized events: one `changed` or `missing` per path per settled burst.
  Stream<WatchEvent> get events => _normalizer.events;

  /// Whether any watcher failed to start.
  ///
  /// The caller degrades to the window-focus sweep rather than showing an
  /// error — doc 07 is explicit that a watcher failure is never a hard error.
  bool get degraded => _degraded;

  /// Directories currently being watched. For tests.
  Iterable<String> get watchedDirectories => _watchers.keys;

  /// Points the watchers at exactly [roots] and the parents of [files].
  ///
  /// Idempotent: directories already watched stay, ones no longer wanted are
  /// cancelled, so this can be called on every change to the open set.
  ///
  /// **Ad-hoc files are watched through their parent directory, never with
  /// `FileWatcher`.** `File.watch` does not work on Windows, so the package
  /// silently substitutes polling on a one-second timer: S5 measured 1000 ms
  /// that way against 7 ms through the parent, for the same file on the same
  /// machine. The cost is events for unrelated files in that directory, which
  /// [registry] and the caller's path filter discard. Do not "simplify" this
  /// back to a per-file watcher.
  void watch({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) {
    if (_disposed) {
      return;
    }
    final wanted = _directoriesFor(roots: roots, files: files);

    for (final directory in _watchers.keys.toList()) {
      if (!wanted.contains(directory)) {
        unawaited(_watchers.remove(directory)?.cancel());
      }
    }
    for (final directory in wanted) {
      if (!_watchers.containsKey(directory)) {
        _start(directory);
      }
    }
  }

  /// The directory set, with anything already covered by a root removed.
  ///
  /// `DirectoryWatcher` is recursive, so watching a folder inside a watched
  /// root is pure duplication — the same save would arrive twice.
  Set<String> _directoriesFor({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) {
    final rootSet = <String>{...roots};
    final candidates = <String>{
      ...rootSet,
      for (final file in files) parentOf(file),
    }..removeWhere((d) => d.isEmpty);

    return <String>{
      for (final candidate in candidates)
        if (!rootSet.any(
          (root) => root != candidate && isInsideDirectory(candidate, root),
        ))
          candidate,
    };
  }

  /// Whether [path] sits under [directory].
  ///
  /// Separator-agnostic, like `basenameOf` and [parentOf], and for the same
  /// reason: a root can reach us from a session file written on the other
  /// operating system. Keying this on `Platform.pathSeparator` looked right on
  /// Windows and quietly watched every directory twice on Linux.
  ///
  /// The trailing separator is not decoration either: without it `/docs2`
  /// counts as being inside `/docs`.
  static bool isInsideDirectory(String path, String directory) {
    final root = _canonical(directory);
    final prefix = root.endsWith('/') ? root : '$root/';
    return _canonical(path).startsWith(prefix);
  }

  static String _canonical(String path) =>
      path.replaceAll(r'\', '/').toLowerCase();

  void _start(String directory) {
    try {
      _watchers[directory] = openWatcher(directory).events.listen(
        _onRaw,
        onError: (Object _) {
          // One directory that cannot be watched degrades to the focus sweep;
          // the rest keep running (doc 07, rule 9).
          _degraded = true;
          unawaited(_watchers.remove(directory)?.cancel());
        },
      );
    } on Object {
      _degraded = true;
    }
  }

  void _onRaw(w.WatchEvent event) {
    // The kind is deliberately dropped here as well as in the normalizer: a
    // deletion and the first half of an atomic save are the same event (S5).
    if (registry.allows(event.path)) {
      _normalizer.add(event.path);
    }
  }

  /// Classifies everything in flight immediately, for the focus sweep.
  void flush() => _normalizer.flush();

  /// Whether anything is waiting on its debounce window.
  bool get hasPending => _normalizer.hasPending;

  /// Stops every watcher and closes the event stream.
  ///
  /// **Awaited, and bounded by [disposeTimeout].** On Windows each watcher is
  /// an isolate wrapped around `ReadDirectoryChangesW` (`package:watcher`'s
  /// default), and an isolate nobody asks to close is left for the VM to tear
  /// down at exit — a plain Dart process holding one never exits at all
  /// (`docs/07`). Asking means the cancel has to actually be dispatched before
  /// the engine goes, which is what awaiting buys; the bound is what stops a
  /// watcher that never answers from becoming the thing that holds the app
  /// open.
  ///
  /// Safe to call twice: the second call finds nothing to cancel.
  Future<void> dispose() async {
    _disposed = true;
    // Each cancel swallows its own error, or one watcher that throws would
    // end `Future.wait` early and leave the rest never asked.
    final cancels = <Future<void>>[
      for (final subscription in _watchers.values)
        subscription.cancel().catchError((Object _) {}),
    ];
    _watchers.clear();
    await Future.wait(cancels).timeout(
      disposeTimeout,
      onTimeout: () => const <void>[],
    );
    await _normalizer.dispose();
  }

  /// The directory containing [path].
  ///
  /// Separator-agnostic for the same reason `basenameOf` is: a path can reach
  /// us from a CLI argument, a drop target, or a session file written on the
  /// other operating system.
  static String parentOf(String path) {
    final name = ExtensionRegistry.basenameOf(path);
    if (name.isEmpty || name.length >= path.length) {
      return '';
    }
    final cut = path.length - name.length;
    final parent = path.substring(0, cut);
    // Keep the separator on a root (`C:\`, `/`); drop it everywhere else.
    return parent.length <= 1 || parent.endsWith(r':\') || parent.endsWith(':/')
        ? parent
        : parent.substring(0, parent.length - 1);
  }
}
