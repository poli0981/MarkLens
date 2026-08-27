import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/watch/watch_service.dart';

/// Everything MarkLens asks of the filesystem watcher.
///
/// A seam for the same reason `WindowLink` is one: a widget test must not
/// start real `inotify`/`ReadDirectoryChangesW` watchers on a temp directory
/// and then race real timers against the test binding's clock. Tests
/// substitute [NoWatchLink], or a fake that lets them push events by hand.
abstract class WatchLink {
  /// Normalized `changed` / `missing` events.
  Stream<WatchEvent> get events;

  /// Points the watchers at exactly these roots and ad-hoc files.
  void sync({required Iterable<String> roots, required Iterable<String> files});

  /// Classifies everything in flight, for the window-focus sweep.
  void flush();

  /// Whether any watcher failed, so the caller can lean on the focus sweep.
  bool get degraded;

  /// Stops every watcher.
  Future<void> dispose();
}

/// The real watcher.
class PlatformWatchLink implements WatchLink {
  /// Creates a link over [service].
  PlatformWatchLink(this.service);

  /// The pure-Dart service underneath.
  final WatchService service;

  @override
  Stream<WatchEvent> get events => service.events;

  @override
  void sync({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) => service.watch(roots: roots, files: files);

  @override
  void flush() => service.flush();

  @override
  bool get degraded => service.degraded;

  @override
  Future<void> dispose() => service.dispose();
}

/// A watcher that is not there.
///
/// What a widget test gets, and also what `files.watchEnabled: false` amounts
/// to — doc 07 degrades a disabled watcher to the focus sweep and the `stale`
/// badge, never to an error.
class NoWatchLink implements WatchLink {
  /// Creates a link that watches nothing.
  const NoWatchLink();

  @override
  Stream<WatchEvent> get events => const Stream<WatchEvent>.empty();

  @override
  void sync({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) {}

  @override
  void flush() {}

  @override
  bool get degraded => false;

  @override
  Future<void> dispose() async {}
}

/// The watcher.
final Provider<WatchLink> watchLinkProvider = Provider<WatchLink>((ref) {
  final link = PlatformWatchLink(
    WatchService(registry: ref.watch(fileServiceProvider).registry),
  );
  ref.onDispose(link.dispose);
  return link;
});
