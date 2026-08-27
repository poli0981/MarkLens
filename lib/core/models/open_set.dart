import 'package:marklens/core/models/opened_file.dart';

/// One document MarkLens knows about, and what the UI needs to say about it.
class OpenEntry {
  /// Creates an entry.
  const OpenEntry({
    required this.file,
    this.pinned = false,
    this.stale = false,
    this.scroll = 0,
  });

  /// The file itself, including the `missing` flag and the change tuple.
  final OpenedFile file;

  /// Pinned tabs stick to the left of the strip (`docs/06_UI_UX.md`).
  final bool pinned;

  /// Changed on disk while this tab was not active.
  ///
  /// Shown as the dot on the tab; the document is re-parsed on the next
  /// activation rather than immediately, so a burst of saves to a background
  /// file costs nothing (`docs/03_DATA_FLOW.md`).
  final bool stale;

  /// Scroll position as a 0..1 ratio, for the session.
  final double scroll;

  /// The dedupe key: the canonical path (`docs/07_FILES_AND_WATCH.md`).
  String get identity => file.identity;

  /// Returns a copy with the given fields replaced.
  OpenEntry copyWith({
    OpenedFile? file,
    bool? pinned,
    bool? stale,
    double? scroll,
  }) => OpenEntry(
    file: file ?? this.file,
    pinned: pinned ?? this.pinned,
    stale: stale ?? this.stale,
    scroll: scroll ?? this.scroll,
  );
}

/// Everything that is open, in the order it is shown.
class OpenSet {
  /// Creates an open set.
  const OpenSet({
    this.entries = const <OpenEntry>[],
    this.roots = const <String>[],
    this.activeIdentity,
    this.recentOrder = const <String>[],
    this.reopenable = const <String>[],
    this.capExceededRoot,
  });

  /// Nothing open.
  static const OpenSet empty = OpenSet();

  /// The open set, in the order the sidebar lists it.
  ///
  /// Flat and ordered rather than a tree: the sidebar builds the tree from the
  /// paths, and doc 05 stores exactly this flat list — ad-hoc files and files
  /// opened from a root alike.
  final List<OpenEntry> entries;

  /// Folder roots, which drive the sidebar's tree mode and the watchers.
  final List<String> roots;

  /// Which entry is showing.
  final String? activeIdentity;

  /// Identities in most-recently-used order, for `Ctrl+Tab`.
  ///
  /// Separate from [entries] because doc 06 asks for MRU cycling over a strip
  /// that stays in its own order — moving tabs around as you cycle is exactly
  /// what makes a cycle unusable.
  final List<String> recentOrder;

  /// Paths of closed documents, newest last, for `Ctrl+Shift+T`.
  final List<String> reopenable;

  /// A root whose scan hit the cap and is waiting on the user's answer.
  final String? capExceededRoot;

  /// The active entry, or `null`.
  OpenEntry? get active {
    for (final entry in entries) {
      if (entry.identity == activeIdentity) {
        return entry;
      }
    }
    return null;
  }

  /// Whether anything is open.
  bool get isEmpty => entries.isEmpty;

  /// The identity of the entry shown at [path], or `null` if it is not open.
  ///
  /// Case-insensitive, because a watcher reports the path the filesystem gives
  /// it and that is not always the casing the entry was opened with — on
  /// Windows it very often is not (`docs/07_FILES_AND_WATCH.md`).
  String? identityForPath(String path) {
    final wanted = path.toLowerCase();
    for (final entry in entries) {
      if (entry.file.path.toLowerCase() == wanted ||
          entry.identity.toLowerCase() == wanted) {
        return entry.identity;
      }
    }
    return null;
  }

  /// The entry for [identity], or `null`.
  OpenEntry? entryFor(String identity) {
    for (final entry in entries) {
      if (entry.identity == identity) {
        return entry;
      }
    }
    return null;
  }

  /// Returns a copy with the given fields replaced.
  ///
  /// [activeIdentity] and [capExceededRoot] are nullable and clearable, so
  /// each takes an explicit flag rather than being unsettable.
  OpenSet copyWith({
    List<OpenEntry>? entries,
    List<String>? roots,
    String? activeIdentity,
    bool clearActive = false,
    List<String>? recentOrder,
    List<String>? reopenable,
    String? capExceededRoot,
    bool clearCapExceeded = false,
  }) => OpenSet(
    entries: entries ?? this.entries,
    roots: roots ?? this.roots,
    activeIdentity: clearActive
        ? null
        : (activeIdentity ?? this.activeIdentity),
    recentOrder: recentOrder ?? this.recentOrder,
    reopenable: reopenable ?? this.reopenable,
    capExceededRoot: clearCapExceeded
        ? null
        : (capExceededRoot ?? this.capExceededRoot),
  );
}
