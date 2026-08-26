import 'dart:convert';
import 'dart:io';

/// How a load went, so the caller can tell the user without guessing.
enum JsonLoadOutcome {
  /// The file was read and parsed.
  ok,

  /// There was no file: a first run, or the config directory was cleared.
  /// Not a problem, and not worth telling anyone about.
  missing,

  /// The file could not be parsed. It was set aside, not deleted, and the
  /// caller starts from defaults and shows a one-time notice (doc 05).
  corrupt,

  /// The file was written by a newer version of MarkLens. It was backed up
  /// and the caller starts from defaults, so a downgrade cannot silently
  /// rewrite a file it does not understand (doc 05, migration policy).
  futureVersion,
}

/// A load: the data, and what happened.
typedef JsonLoadResult = ({Map<String, Object?> data, JsonLoadOutcome outcome});

/// The one place MarkLens writes to disk.
///
/// `session.json` and `settings.json` are the app's entire disk footprint
/// besides its installation (CLAUDE.md rule 1), and both go through here so
/// the write discipline in `docs/05_SESSION_AND_SETTINGS.md` is implemented
/// once: temp file, flushed, renamed over the original.
///
/// The [directory] is injected rather than resolved: `path_provider` is a
/// Flutter plugin and `core/` is pure Dart (rule 3). `app/providers.dart`
/// resolves it once during bootstrap, and tests hand over a temp directory
/// with no mocking at all.
///
/// This is also why `lib/core/storage/` appears in the write allowlist of
/// `test/architecture/no_write_test.dart`. The rule that test enforces is that
/// MarkLens writes nothing but its own config; this class is the
/// implementation of that write, not an exception to it, and
/// `test/core/json_store_test.dart` asserts it touches nothing outside the
/// directory it was given.
class JsonStore {
  /// Creates a store for `<name>.json` inside [directory].
  const JsonStore({required this.directory, required this.name});

  /// The app's config directory. Nothing outside it is ever written.
  final Directory directory;

  /// The file's base name, without extension — `session` or `settings`.
  final String name;

  /// The file this store reads and writes.
  File get file => File(_pathFor('$name.json'));

  /// Reads and decodes the file.
  ///
  /// Never throws. A file that is absent, unreadable, not JSON, or JSON that
  /// is not an object all come back as an empty map with an outcome saying
  /// which — the caller then starts from defaults (rule 9).
  JsonLoadResult load() {
    final String text;
    try {
      if (!file.existsSync()) {
        return (
          data: const <String, Object?>{},
          outcome: JsonLoadOutcome.missing,
        );
      }
      text = file.readAsStringSync();
    } on FileSystemException {
      return (
        data: const <String, Object?>{},
        outcome: JsonLoadOutcome.corrupt,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      quarantine('corrupt');
      return (
        data: const <String, Object?>{},
        outcome: JsonLoadOutcome.corrupt,
      );
    }

    if (decoded is! Map<String, Object?>) {
      quarantine('corrupt');
      return (
        data: const <String, Object?>{},
        outcome: JsonLoadOutcome.corrupt,
      );
    }
    return (data: decoded, outcome: JsonLoadOutcome.ok);
  }

  /// Writes [data] atomically.
  ///
  /// Temp file first, flushed to disk, then renamed over the original — so a
  /// crash or a power cut leaves either the old file or the new one, never a
  /// half-written one. Rename is atomic on both NTFS and ext4 when source and
  /// destination are in the same directory, which they are by construction.
  ///
  /// Returns whether the write landed. A failure is reported rather than
  /// thrown: losing a session write is a small thing, and taking the app down
  /// over it is not.
  bool save(Map<String, Object?> data) {
    final temporary = File(_pathFor('$name.json.tmp'));
    try {
      if (!directory.existsSync()) {
        // Deferred until the first write, so simply launching MarkLens touches
        // no disk at all (docs/05).
        directory.createSync(recursive: true);
      }
      temporary
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(data),
          flush: true,
        )
        ..renameSync(file.path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Sets the current file aside under a timestamped name.
  ///
  /// The evidence is kept rather than deleted: a corrupt session file is the
  /// only copy of what the user had open, and a file from a future version is
  /// what they will want back when they upgrade again (doc 05).
  ///
  /// [reason] becomes part of the name — `corrupt` or `bak`.
  bool quarantine(String reason) {
    try {
      if (!file.existsSync()) {
        return false;
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      file.renameSync(_pathFor('$name.json.$reason-$stamp'));
      return true;
    } on FileSystemException {
      return false;
    }
  }

  String _pathFor(String fileName) =>
      '${directory.path}${Platform.pathSeparator}$fileName';
}
