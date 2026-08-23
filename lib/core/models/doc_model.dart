import 'package:marklens/core/models/outline.dart';

/// The complete result of parsing one document — and the point at which
/// `core/markdown/` stops.
///
/// Turning a [DocModel] into widgets is the job of `MarkdownRenderer` in
/// `features/reader/rendering/`. This split is what keeps `core/` pure Dart
/// (CLAUDE.md rule 3) while leaving the renderer swappable (rule 6). See
/// `docs/02_ARCHITECTURE.md`, "The seam".
class DocModel {
  /// Creates a parsed document.
  const DocModel({
    required this.path,
    required this.sanitizedSource,
    required this.outline,
    required this.blocks,
    this.frontMatter,
    this.notices = const <DocNotice>[],
  });

  /// Canonical absolute path of the source file. Identity for the open set,
  /// the cache key and the session file (docs/07_FILES_AND_WATCH.md).
  final String path;

  /// The Markdown handed to the renderer: front-matter removed, and for
  /// `.mdx` files, JSX already transformed to inert placeholders.
  ///
  /// The renderer never sees the raw file, so it can never be handed anything
  /// executable (CLAUDE.md rule 2).
  final String sanitizedSource;

  /// Headings, in document order.
  final Outline outline;

  /// Source line ranges of every top-level block, in document order.
  final List<SourceBlock> blocks;

  /// Parsed leading `---` block, or `null` when the document has none.
  final FrontMatter? frontMatter;

  /// Non-fatal problems encountered while parsing.
  ///
  /// Every one of these must degrade rather than throw (CLAUDE.md rule 9).
  final List<DocNotice> notices;
}

/// A top-level block of the source, located by line and byte offset.
///
/// The `markdown` package's AST carries no source positions, so the pipeline
/// builds this index itself. It is what search hits and `#anchor` jumps aim
/// at — see `docs/04_MARKDOWN_PIPELINE.md`.
class SourceBlock {
  /// Creates a block spanning [startLine]–[endLine].
  const SourceBlock({
    required this.index,
    required this.startLine,
    required this.endLine,
    required this.startOffset,
    required this.endOffset,
  });

  /// Position of this block in document order, starting at 0.
  final int index;

  /// First source line of the block, 0-based, inclusive.
  final int startLine;

  /// Last source line of the block, 0-based, inclusive.
  final int endLine;

  /// Offset of the block's first character in the source string.
  final int startOffset;

  /// Offset one past the block's last character in the source string.
  final int endOffset;

  /// Whether [offset] falls inside this block.
  bool contains(int offset) => offset >= startOffset && offset < endOffset;
}

/// A document's leading `---` front-matter block.
class FrontMatter {
  /// Creates a front-matter model.
  const FrontMatter({
    required this.raw,
    required this.fields,
    required this.parsed,
  });

  /// The block exactly as written, fences excluded.
  ///
  /// Always retained: when [parsed] is false this is what the panel shows,
  /// because throwing away the user's text to report an error is worse than
  /// showing it (docs/04_MARKDOWN_PIPELINE.md).
  final String raw;

  /// Simple `key: value` pairs, empty when [parsed] is false.
  final Map<String, String> fields;

  /// Whether every line parsed as a simple `key: value` pair.
  final bool parsed;
}

/// Something the reader should be told about, without blocking the document.
///
/// A notice carries a [kind] and its data, never a message string: the text is
/// resolved through ARB at the widget layer (CLAUDE.md rule 4, docs/09_I18N).
class DocNotice {
  /// Creates a notice.
  const DocNotice(this.kind, {this.detail});

  /// What went wrong.
  final DocNoticeKind kind;

  /// Optional non-translatable detail, such as a path or a component name.
  final String? detail;
}

/// The closed set of non-fatal parse problems.
enum DocNoticeKind {
  /// The file was not valid UTF-8 and was decoded lossily.
  invalidUtf8,

  /// The front-matter block is not simple `key: value` lines; it is shown raw.
  frontMatterUnparsed,

  /// An MDX construct could not be classified and was emitted as a code
  /// block. Bailing out is correct behaviour, not an error (docs/04).
  mdxBailOut,

  /// Parsing failed outright; the document is shown as plain text.
  plainTextFallback,

  /// The document is over the large-file threshold (docs/04).
  largeDocument,
}
