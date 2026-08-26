import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/cache/doc_cache.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/opened_file.dart';

/// Which document the reader is showing.
@immutable
class ActiveDocument {
  /// Creates a state.
  const ActiveDocument({this.file, this.doc, this.failedPath});

  /// Nothing open — the empty state.
  static const ActiveDocument none = ActiveDocument();

  /// The file's metadata, or `null` when nothing is open.
  final OpenedFile? file;

  /// The parsed document, or `null` when nothing is open.
  final DocModel? doc;

  /// The path of the last open that failed, for the message.
  ///
  /// A separate field rather than an error inside [doc]: a document that
  /// could not be read at all is not a document with a notice, it is the
  /// absence of one.
  final String? failedPath;

  /// Whether there is something to render.
  bool get hasDocument => doc != null;
}

/// Opens documents: metadata, bytes, cache, pipeline.
///
/// This is the activation path of `docs/03_DATA_FLOW.md`, and the order is the
/// point — a cache hit must not read the file again, and a parse must not
/// happen twice for a document that has not changed.
class ActiveDocumentController extends Notifier<ActiveDocument> {
  @override
  ActiveDocument build() => ActiveDocument.none;

  /// Opens [path], parsing it unless the cache already has it.
  ///
  /// Reports failure through [ActiveDocument.failedPath] rather than throwing:
  /// a file chosen from a dialog can be gone, unreadable or not a file at all
  /// by the time it is opened, and none of those is worth an exception.
  void open(String path) {
    final files = ref.read(fileServiceProvider);
    final entry = files.describe(path);
    if (entry == null) {
      state = ActiveDocument(failedPath: path);
      return;
    }

    final cache = ref.read(docCacheProvider);
    final key = DocCache.keyFor(entry);
    final cached = cache.get(key);
    if (cached != null) {
      state = ActiveDocument(file: entry, doc: cached);
      return;
    }

    final bytes = files.readBytes(entry.path);
    if (bytes == null) {
      state = ActiveDocument(failedPath: path);
      return;
    }

    final doc = ref
        .read(markdownPipelineProvider)
        .parse(
          path: entry.path,
          bytes: bytes,
          isMdx: files.registry.isMdx(entry.path),
        );
    cache.put(key, doc);
    state = ActiveDocument(file: entry, doc: doc);
  }

  /// Re-reads the active document from disk, ignoring the cache.
  ///
  /// File → Reload, and the watch handler once it lands. The cache entry is
  /// invalidated by identity rather than by key, because the key it was stored
  /// under describes the version that has just been replaced.
  void reload() {
    final path = state.file?.path;
    if (path == null) {
      return;
    }
    final identity = state.file?.identity;
    if (identity != null) {
      ref.read(docCacheProvider).invalidate(identity);
    }
    open(path);
  }

  /// Returns to the empty state.
  void close() => state = ActiveDocument.none;
}

/// The active document provider.
final NotifierProvider<ActiveDocumentController, ActiveDocument>
activeDocumentProvider =
    NotifierProvider<ActiveDocumentController, ActiveDocument>(
      ActiveDocumentController.new,
    );
