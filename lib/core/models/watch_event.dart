/// What happened to a watched document, after normalization.
///
/// The raw stream from a filesystem watcher is noisier than this: a single
/// save can arrive as `modify`, or as `remove` then `add`, depending on how
/// the editor writes (spike S5). `WatchNormalizer` collapses all of that into
/// these two.
enum WatchEventKind {
  /// The document is still there and its contents may differ.
  ///
  /// Covers every save shape: written in place, replaced atomically, deleted
  /// and recreated, or renamed away and rewritten.
  changed,

  /// The document is gone, and stayed gone past the debounce window.
  ///
  /// The entry keeps its place in the open set with a `missing` badge; it is
  /// pruned only when the user closes it (`docs/07_FILES_AND_WATCH.md`).
  missing,
}

/// One normalized filesystem event for one document.
class WatchEvent {
  /// Creates a watch event.
  const WatchEvent({required this.path, required this.kind});

  /// Canonical absolute path of the document.
  final String path;

  /// What happened to it.
  final WatchEventKind kind;

  @override
  String toString() => 'WatchEvent(${kind.name}, $path)';
}
