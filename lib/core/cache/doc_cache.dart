import 'dart:collection';

import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/opened_file.dart';

/// What makes one parse of one document distinct from another.
///
/// A record rather than a class so equality is structural for free, which is
/// the whole requirement for a map key.
typedef DocCacheKey = ({
  /// The canonical path, symlinks resolved (`OpenedFile.identity`).
  String identity,

  /// Last modification time at the moment the document was parsed.
  DateTime modified,

  /// Size in bytes at that moment.
  int size,

  /// Bumped when a setting that changes parse *output* changes.
  int settingsRevision,
});

/// An LRU of parsed documents.
///
/// It caches **parse output, never widgets** (CLAUDE.md rule 8): a Flutter
/// element tree does not survive a tab switch anyway, and parsing is the
/// expensive half. Forty entries by default, which is the number the charter's
/// RAM budget is written against.
///
/// ## The key, and why it is this key
///
/// Three documents specified three different keys — doc 02 `path + mtime +
/// settingsRevision`, doc 03 `path + mtime`, doc 07 an `mtime + size` tuple for
/// change detection — so this is the reconciliation, and docs 02, 03, 07 and 15
/// were amended to match it.
///
/// - **`identity`, not `path`.** Doc 07 makes the canonical path the identity
///   of a file. Keying on the displayed path would cache the same document
///   twice when it is reached through a symlink or a differently-cased path.
/// - **`size` as well as `mtime`.** Doc 07 introduces the pair precisely
///   because a rewrite can land inside one filesystem timestamp tick, and then
///   says the cache key "includes mtime, so staleness is structural". That is
///   only true with both halves; mtime alone reintroduces the very miss the
///   tuple exists to prevent.
/// - **`settingsRevision`, and it is inert in v1.** Doc 02 names it, so it is
///   here. No setting in the doc 05 schema actually changes parse output:
///   `reading.frontMatter` selects how the panel displays a block the splitter
///   lifts out either way, `network.allowRemoteImages` is resolved at image
///   load, and `files.extensions` decides what opens rather than how it parses.
///   It stays at zero until a setting that changes a `DocModel` exists, and it
///   is kept rather than dropped so that setting cannot be added without
///   someone meeting this comment.
///
/// Because the key carries the tuple, a changed file simply misses — staleness
/// is structural rather than something a caller has to remember. [invalidate]
/// exists to release the memory promptly on a watch event, not to make
/// correctness work.
class DocCache {
  /// Creates a cache holding at most [capacity] documents.
  DocCache({this.capacity = defaultCapacity})
    : assert(capacity > 0, 'a cache that holds nothing is a bug, not a config');

  /// The doc 02 default, matched to the charter's RAM budget.
  static const int defaultCapacity = 40;

  /// How many documents are kept before the least recently used is dropped.
  final int capacity;

  /// Insertion-ordered, and reordered on every hit, so the first key is always
  /// the least recently used.
  final LinkedHashMap<DocCacheKey, DocModel> _entries =
      LinkedHashMap<DocCacheKey, DocModel>();

  /// How many documents are held.
  int get length => _entries.length;

  /// The keys held, least recently used first.
  Iterable<DocCacheKey> get keys => _entries.keys;

  /// The key for [file], as of the moment it was last looked at.
  static DocCacheKey keyFor(OpenedFile file, {int settingsRevision = 0}) => (
    identity: file.identity,
    modified: file.modified,
    size: file.size,
    settingsRevision: settingsRevision,
  );

  /// The cached parse for [key], or `null`.
  ///
  /// A hit becomes the most recently used entry, which is what makes the
  /// eviction order mean anything.
  DocModel? get(DocCacheKey key) {
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit;
    }
    return hit;
  }

  /// Stores [doc] under [key], evicting the least recently used if needed.
  void put(DocCacheKey key, DocModel doc) {
    _entries
      ..remove(key)
      ..[key] = doc;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Drops every parse of the document with this [identity].
  ///
  /// Called on a watch event. There can be more than one entry for a file —
  /// an older mtime, a different settings revision — and all of them are now
  /// describing a document that no longer exists in that form.
  ///
  /// Returns how many entries were dropped, which is what the tests assert on.
  int invalidate(String identity) {
    final before = _entries.length;
    _entries.removeWhere((key, _) => key.identity == identity);
    return before - _entries.length;
  }

  /// Drops everything.
  ///
  /// For a settings change that alters parse output — which no v1 setting
  /// does — and for closing a folder.
  void clear() => _entries.clear();
}
