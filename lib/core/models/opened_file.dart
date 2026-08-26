import 'package:marklens/core/files/extension_registry.dart';

/// One entry in the open set: a document MarkLens knows about, whether or not
/// it is currently parsed.
///
/// The sidebar renders these without parsing anything, which is what keeps a
/// thousand restored entries free at startup (`docs/03_DATA_FLOW.md`).
class OpenedFile {
  /// Creates an entry.
  const OpenedFile({
    required this.path,
    required this.identity,
    required this.modified,
    required this.size,
    this.missing = false,
  });

  /// Absolute path as it should be shown and opened, in its on-disk casing.
  final String path;

  /// The canonical path, with symlinks resolved — the identity of this entry.
  ///
  /// Separate from [path] because the two answer different questions. Identity
  /// has to be stable and case-folded so the same file reached two ways is one
  /// entry (`docs/07_FILES_AND_WATCH.md`); the displayed path has to keep the
  /// casing the user gave their folders. It is what the open set dedupes on,
  /// what the session file stores, and part of the document cache key.
  final String identity;

  /// Last modification time, half of the change-detection tuple.
  final DateTime modified;

  /// Size in bytes, the other half.
  ///
  /// Size is carried alongside [modified] because a file can be rewritten
  /// inside one filesystem timestamp tick; doc 07 specifies the pair.
  final int size;

  /// Whether the file was gone the last time it was looked at.
  ///
  /// A missing file keeps its entry and gets a badge rather than vanishing:
  /// entries leave the session only when the user closes them (doc 07).
  final bool missing;

  /// The file name, without its directory.
  String get name => ExtensionRegistry.basenameOf(path);

  @override
  String toString() =>
      'OpenedFile($path${missing ? ', missing' : ', $size bytes'})';
}
