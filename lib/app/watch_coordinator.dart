import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/watch/watch_service.dart';

/// Turns watch events into changes to the open set (`docs/03_DATA_FLOW.md`,
/// "Watch → reload").
///
/// This is the answer to "how does a watch event reach the reader without one
/// feature importing another": no feature is involved. Watching is
/// cross-cutting wiring, so it lives in `app/`, beside the composition root,
/// and the sidebar, the tab strip and the reader all just observe the state it
/// changes — every badge it raises was already being drawn.
class WatchCoordinator {
  /// Creates a coordinator over [ref].
  WatchCoordinator(this.ref);

  /// The scope this coordinator reads and writes.
  final Ref ref;

  StreamSubscription<WatchEvent>? _events;
  Set<String> _roots = const <String>{};
  Set<String> _files = const <String>{};

  /// Starts watching, and keeps the watched set in step with what is open.
  void start() {
    _events = ref.read(watchLinkProvider).events.listen(_onEvent);

    // The open set changes for many reasons — a pin, a scroll, an activation —
    // and almost none of them change *which directories* matter. Comparing the
    // derived set is what stops every one of those from tearing down and
    // restarting a platform watcher.
    ref
      ..listen(openSetProvider, (_, _) => _syncWatched())
      ..listen(
        settingsProvider.select((settings) => settings.files.watchEnabled),
        (_, _) => _syncWatched(),
      );
    _syncWatched();
  }

  /// The window came back. Re-stat everything and settle anything in flight.
  ///
  /// Doc 03's fallback for whatever the watcher missed, and the whole story
  /// when watching is switched off.
  void sweep() {
    ref.read(openSetProvider.notifier).refreshAll();
    ref.read(watchLinkProvider).flush();
  }

  void _syncWatched() {
    final enabled = ref.read(settingsProvider).files.watchEnabled;
    final set = ref.read(openSetProvider);

    // Watching off means watching nothing — not a disabled flag checked
    // somewhere downstream (doc 07).
    final roots = enabled ? <String>{...set.roots} : const <String>{};
    final files = enabled
        ? <String>{
            for (final entry in set.entries)
              if (!_isUnderRoot(entry.file.path, roots)) entry.file.path,
          }
        : const <String>{};

    if (_setsEqual(roots, _roots) && _setsEqual(files, _files)) {
      return;
    }
    _roots = roots;
    _files = files;
    ref.read(watchLinkProvider).sync(roots: roots, files: files);
  }

  /// Whether [path] is already covered by one of the watched [roots].
  ///
  /// Shares `WatchService`'s comparison rather than case-folding and comparing
  /// prefixes here: that version treated `/docs2/note.md` as living under
  /// `/docs`, and keyed on the platform separator, which is wrong for a root
  /// restored from a session written on the other operating system.
  static bool _isUnderRoot(String path, Set<String> roots) =>
      roots.any((root) => WatchService.isInsideDirectory(path, root));

  static bool _setsEqual(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  void _onEvent(WatchEvent event) {
    final openSet = ref.read(openSetProvider);
    // Watching a directory means hearing about every document in it, including
    // ones nobody opened. Those are not ours.
    final identity = openSet.identityForPath(event.path);
    if (identity == null) {
      return;
    }

    final notifier = ref.read(openSetProvider.notifier);
    if (event.kind == WatchEventKind.missing) {
      // The entry stays and gains the badge; it leaves only when the user
      // closes it (doc 07).
      notifier.refreshEntry(identity);
      return;
    }

    if (identity != openSet.activeIdentity) {
      notifier.markStale(identity);
      return;
    }

    // The active document re-parses. Invalidating by identity rather than by
    // key, because the key it was stored under describes the version that has
    // just been replaced; re-stat first, or the new key is never built.
    ref.read(docCacheProvider).invalidate(identity);
    notifier.refreshEntry(identity);
  }

  /// Stops listening.
  ///
  /// Called by the exit sequence on a real close, and by the scope when a
  /// test tears the container down — so it has to be safe twice, and it is:
  /// cancelling a cancelled subscription is a no-op. The link itself is
  /// disposed the same two ways (`docs/03_DATA_FLOW.md`, "App exit").
  void dispose() => unawaited(_events?.cancel());
}

/// The watch coordinator.
final Provider<WatchCoordinator> watchCoordinatorProvider =
    Provider<WatchCoordinator>((ref) {
      final coordinator = WatchCoordinator(ref);
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// The directory a file is watched through, exposed for the shell's tests.
///
/// Ad-hoc files are watched by their parent, never with `FileWatcher` (S5).
String watchDirectoryFor(String path) => WatchService.parentOf(path);
