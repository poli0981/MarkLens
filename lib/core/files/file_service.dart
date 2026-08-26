import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/files/natural_sort.dart';
import 'package:marklens/core/models/opened_file.dart';

/// What a scan found, and whether it stopped early.
typedef ScanResult = ({List<OpenedFile> files, bool capExceeded});

/// Finds the documents MarkLens will open, and keeps their identities straight.
///
/// Read-only throughout (CLAUDE.md rule 1): this class lists, stats and
/// resolves, and never creates, moves or removes anything.
///
/// Everything about *which* files count lives in [ExtensionRegistry], and
/// everything about *how they are ordered* lives in `compareNatural`, so this
/// class is only the walk itself (`docs/07_FILES_AND_WATCH.md`).
class FileService {
  /// Creates a service.
  const FileService({
    this.registry = ExtensionRegistry.standard,
    this.fileCap = defaultFileCap,
  });

  /// The doc 05 default cap on how many entries one scan may open.
  static const int defaultFileCap = 1000;

  /// Which extensions count.
  final ExtensionRegistry registry;

  /// How many files a scan will collect before it stops and reports.
  ///
  /// Soft, and deliberately so: on exceeding it the scan reports rather than
  /// truncating, and the caller offers "Open first N / Cancel" (doc 07). A
  /// scan that silently returned the first thousand of five thousand files
  /// would look exactly like a folder with a thousand files.
  final int fileCap;

  /// Walks [roots] breadth-first and returns the documents found.
  ///
  /// Breadth-first so the shallow files — the ones a reader is most likely to
  /// want — arrive first, which is also what makes a streaming sidebar useful
  /// later. Within a directory, sub-directories are visited before files and
  /// both are ordered by [compareNatural].
  ///
  /// Symlinked **directories** are skipped for cycle safety; symlinked files
  /// are followed. Dot-prefixed entries are skipped. Anything that cannot be
  /// read — a permission error, a link to nowhere — is skipped rather than
  /// raised: a folder scan must not fail because one entry in it is odd.
  ScanResult scanRoots(Iterable<String> roots) {
    final files = <OpenedFile>[];
    final seen = <String>{};
    final queue = Queue<String>();

    for (final root in roots) {
      final absolute = _absolute(root);
      if (absolute != null && seen.add(_identityOfDirectory(absolute))) {
        queue.add(absolute);
      }
    }

    while (queue.isNotEmpty) {
      final children = _childrenOf(queue.removeFirst());

      for (final directory in children.directories) {
        if (seen.add(_identityOfDirectory(directory))) {
          queue.add(directory);
        }
      }

      for (final file in children.files) {
        final entry = describe(file);
        if (entry == null || !seen.add(entry.identity)) {
          continue;
        }
        if (files.length == fileCap) {
          return (files: files, capExceeded: true);
        }
        files.add(entry);
      }
    }

    return (files: files, capExceeded: false);
  }

  /// Runs [scanRoots] off the UI isolate.
  ///
  /// Only primitives cross the boundary, so the closure stays sendable and the
  /// service does not have to be.
  Future<ScanResult> scanRootsInBackground(Iterable<String> roots) {
    final paths = roots.toList(growable: false);
    final extensions = registry.extensions;
    final cap = fileCap;
    return Isolate.run(
      () => FileService(
        registry: ExtensionRegistry(extensions),
        fileCap: cap,
      ).scanRoots(paths),
    );
  }

  /// Describes one file by path, whatever its extension.
  ///
  /// Extension filtering is the *scan's* rule, not this one: a file named on
  /// the command line opens even if MarkLens would not have found it itself
  /// (doc 07 — "user intent wins, rendering doesn't").
  ///
  /// Returns `null` when the path is not a readable file at all, so a caller
  /// can tell "not a document" from "a document that is currently missing".
  OpenedFile? describe(String path) {
    final absolute = _absolute(path);
    if (absolute == null) {
      return null;
    }
    final stat = FileStat.statSync(absolute);
    if (stat.type != FileSystemEntityType.file) {
      return null;
    }
    return OpenedFile(
      path: absolute,
      identity: _identityOfFile(absolute),
      modified: stat.modified,
      size: stat.size,
    );
  }

  /// Re-reads [entry] from disk, for the watch handler and the focus sweep.
  ///
  /// A file that has gone keeps its entry and comes back flagged, because
  /// entries leave the session only when the user closes them (doc 07). One
  /// that reappears comes back with a fresh tuple and the flag cleared.
  OpenedFile refresh(OpenedFile entry) {
    final stat = FileStat.statSync(entry.path);
    if (stat.type != FileSystemEntityType.file) {
      return OpenedFile(
        path: entry.path,
        identity: entry.identity,
        modified: entry.modified,
        size: entry.size,
        missing: true,
      );
    }
    return OpenedFile(
      path: entry.path,
      identity: entry.identity,
      modified: stat.modified,
      size: stat.size,
    );
  }

  /// Whether [entry] has changed on disk since it was last read.
  ///
  /// The `mtime + size` pair rather than mtime alone: a rewrite can land
  /// inside one filesystem timestamp tick, and doc 07 specifies the tuple.
  bool hasChanged(OpenedFile entry) {
    final current = refresh(entry);
    return current.missing != entry.missing ||
        current.modified != entry.modified ||
        current.size != entry.size;
  }

  /// The directories and files directly under [directory], in visit order.
  ({List<String> directories, List<String> files}) _childrenOf(
    String directory,
  ) {
    final List<FileSystemEntity> entities;
    try {
      // followLinks: false so a symlink arrives as a Link and can be judged
      // on what it points at, rather than silently becoming its target.
      entities = Directory(directory).listSync(followLinks: false);
    } on FileSystemException {
      // An unreadable directory is skipped, not fatal. A docs folder with one
      // permission-denied subdirectory still opens.
      return (directories: const <String>[], files: const <String>[]);
    }

    final directories = <String>[];
    final files = <String>[];

    for (final entity in entities) {
      final path = entity.path;
      if (ExtensionRegistry.isHidden(path)) {
        continue;
      }

      final type = _classify(entity);
      if (type == FileSystemEntityType.directory) {
        directories.add(path);
      } else if (type == FileSystemEntityType.file && registry.allows(path)) {
        files.add(path);
      }
    }

    directories.sort(_byName);
    files.sort(_byName);
    return (directories: directories, files: files);
  }

  /// What [entity] should be treated as.
  ///
  /// A symlink is resolved one step: pointing at a file it is followed,
  /// pointing at a directory it is skipped entirely, because a link back up
  /// the tree would otherwise make the walk run forever. The `seen` set
  /// guards real cycles too, but skipping is what doc 07 specifies.
  static FileSystemEntityType _classify(FileSystemEntity entity) {
    if (entity is! Link) {
      return entity is Directory
          ? FileSystemEntityType.directory
          : FileSystemEntityType.file;
    }
    final String target;
    try {
      target = entity.resolveSymbolicLinksSync();
    } on FileSystemException {
      // A link to nowhere.
      return FileSystemEntityType.notFound;
    }
    final type = FileStat.statSync(target).type;
    // A symlinked directory is reported as nothing at all, which is how the
    // walk skips it.
    return type == FileSystemEntityType.directory
        ? FileSystemEntityType.notFound
        : type;
  }

  static int _byName(String a, String b) => compareNatural(
    ExtensionRegistry.basenameOf(a),
    ExtensionRegistry.basenameOf(b),
  );

  /// [path] made absolute, or `null` if it is not usable as one.
  static String? _absolute(String path) {
    if (path.trim().isEmpty) {
      return null;
    }
    return File(path).absolute.path;
  }

  /// The dedupe key for a file: symlinks resolved, canonical casing.
  ///
  /// `resolveSymbolicLinksSync` is what makes two paths to one file compare
  /// equal — it follows links and, on Windows, returns the casing the
  /// filesystem actually holds. It needs the file to exist, so a path that
  /// cannot be resolved falls back to a case-folded form: worse, but never
  /// worse than crashing a scan.
  static String _identityOfFile(String path) {
    try {
      return _stripWindowsPrefix(File(path).resolveSymbolicLinksSync());
    } on FileSystemException {
      return path.toLowerCase();
    }
  }

  static String _identityOfDirectory(String path) {
    try {
      return _stripWindowsPrefix(Directory(path).resolveSymbolicLinksSync());
    } on FileSystemException {
      return path.toLowerCase();
    }
  }

  /// Drops the `\\?\` long-path prefix Windows sometimes returns, so the same
  /// file resolved two ways yields the same string.
  static String _stripWindowsPrefix(String path) =>
      path.startsWith(r'\\?\') ? path.substring(4) : path;
}
