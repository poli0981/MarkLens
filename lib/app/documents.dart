import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/cache/doc_cache.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/opened_file.dart';

/// What the reader is showing.
@immutable
class ActiveDocument {
  /// Creates a state.
  const ActiveDocument({this.file, this.doc, this.failedPath});

  /// Nothing open — the empty state.
  static const ActiveDocument none = ActiveDocument();

  /// The file's metadata, or `null` when nothing is open.
  final OpenedFile? file;

  /// The parsed document, or `null` when nothing is open or it could not be
  /// read.
  final DocModel? doc;

  /// The path of a document that could not be read at all.
  ///
  /// A separate field rather than a notice inside [doc]: a file that has gone
  /// is not a document with a problem, it is the absence of one. The tab stays
  /// with its `missing` badge (doc 07) while the reader shows nothing.
  final String? failedPath;

  /// Whether there is something to render.
  bool get hasDocument => doc != null;
}

/// Parses whichever document the open set has made active.
///
/// This is the activation path of `docs/03_DATA_FLOW.md`, and it is derived
/// rather than driven: the open set decides *what* is showing, and this decides
/// what that costs. Rebuilding only when the active document's identity or its
/// `mtime + size` changes is what stops a pin, a scroll or another tab opening
/// from re-parsing anything.
class ActiveDocumentController extends Notifier<ActiveDocument> {
  @override
  ActiveDocument build() {
    // A record, so the comparison is structural: watching the OpenEntry itself
    // would rebuild on every unrelated change to the open set, and watching
    // only the identity would miss a file changing underneath it.
    final key = ref.watch(
      openSetProvider.select((set) {
        final entry = set.active;
        return entry == null
            ? null
            : (
                identity: entry.identity,
                modified: entry.file.modified,
                size: entry.file.size,
                missing: entry.file.missing,
              );
      }),
    );
    if (key == null) {
      return ActiveDocument.none;
    }

    final file = ref.read(openSetProvider).active?.file;
    return file == null ? ActiveDocument.none : _load(file);
  }

  ActiveDocument _load(OpenedFile file) {
    if (file.missing) {
      return ActiveDocument(file: file, failedPath: file.path);
    }

    final cache = ref.read(docCacheProvider);
    final cacheKey = DocCache.keyFor(file);
    final cached = cache.get(cacheKey);
    if (cached != null) {
      return ActiveDocument(file: file, doc: cached);
    }

    final bytes = ref.read(fileServiceProvider).readBytes(file.path);
    if (bytes == null) {
      return ActiveDocument(file: file, failedPath: file.path);
    }

    final doc = ref
        .read(markdownPipelineProvider)
        .parse(
          path: file.path,
          bytes: bytes,
          isMdx: ref.read(fileServiceProvider).registry.isMdx(file.path),
        );
    cache.put(cacheKey, doc);
    return ActiveDocument(file: file, doc: doc);
  }

  /// Re-reads the active document from disk, ignoring the cache.
  ///
  /// File → Reload, and the watch handler once it lands. The cache is
  /// invalidated by identity rather than by key, because the key the document
  /// was stored under describes the version that has just been replaced.
  void reload() {
    final identity = state.file?.identity;
    if (identity == null) {
      return;
    }
    ref.read(docCacheProvider).invalidate(identity);
    // Re-stat first: a reload after an external edit has a new mtime and size,
    // and the cache key has to be the new one or the next activation serves
    // the stale parse straight back.
    ref.read(openSetProvider.notifier).refreshAll();
    ref.invalidateSelf();
  }
}

/// The active document provider.
final NotifierProvider<ActiveDocumentController, ActiveDocument>
activeDocumentProvider =
    NotifierProvider<ActiveDocumentController, ActiveDocument>(
      ActiveDocumentController.new,
    );

/// How far through the active document the reader is scrolled, as a 0..1 ratio.
///
/// Kept apart from [ActiveDocument] on purpose. The document changes when a tab
/// is activated or a file is re-parsed; the position changes while someone is
/// reading. Folding the second into the first would put every dependent of the
/// parse path — the reader, the outline, the cache key — behind a value that
/// moves as the wheel turns.
///
/// The reader reports it only when the whole percent changes (`ReaderView`),
/// which is the resolution the status bar displays.
class ReaderPositionController extends Notifier<double> {
  @override
  double build() => 0;

  /// Records where the reader is now.
  void record(double ratio) => state = ratio.clamp(0.0, 1.0);
}

/// The reader-position provider.
final NotifierProvider<ReaderPositionController, double>
readerPositionProvider = NotifierProvider<ReaderPositionController, double>(
  ReaderPositionController.new,
);
