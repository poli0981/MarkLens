import 'package:marklens/core/markdown/word_count.dart';
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
  ///
  /// [wordCount] is derived here rather than passed in, which is why this
  /// constructor is not `const`. The status bar shows the number
  /// (`docs/06_UI_UX.md`), and a count that arrived as a separate argument
  /// could disagree with the text beside it; computing it from
  /// [sanitizedSource] makes that unrepresentable. The cost is one linear scan
  /// per parse, against a parse that is already linear.
  DocModel({
    required this.path,
    required this.rawSource,
    required this.sanitizedSource,
    required this.outline,
    required this.blocks,
    this.frontMatter,
    this.notices = const <DocNotice>[],
    this.mdxImportsHidden = 0,
  }) : wordCount = countWords(sanitizedSource);

  /// Canonical absolute path of the source file. Identity for the open set,
  /// the cache key and the session file (docs/07_FILES_AND_WATCH.md).
  final String path;

  /// The file exactly as decoded: BOM stripped, front matter still present,
  /// nothing rewritten.
  ///
  /// This is what File → Copy entire document copies (`docs/06_UI_UX.md`).
  /// [sanitizedSource] cannot serve that purpose despite what doc 06 first
  /// said: it has the front matter lifted out and block HTML rewritten, so
  /// copying it would silently drop the user's front matter. A lossily decoded
  /// file carries U+FFFD here, in place of the bytes that were not UTF-8.
  final String rawSource;

  /// The Markdown handed to the renderer: front-matter removed, block HTML
  /// rewritten into inert fenced blocks, and for `.mdx` files, JSX transformed
  /// to inert placeholders.
  ///
  /// The renderer never sees the raw file, so it can never be handed anything
  /// executable (CLAUDE.md rule 2). It is also the string [blocks] indexes.
  final String sanitizedSource;

  /// Headings, in document order.
  final Outline outline;

  /// Every top-level block, in the order the renderer builds them.
  ///
  /// One entry per top-level node of the parse, so `blocks[i]` corresponds to
  /// the renderer's `children[2i]` (`docs/01_TECH_STACK.md`). May be empty: an
  /// empty file has no blocks, and neither does one containing only blank
  /// lines or only link-reference definitions.
  final List<SourceBlock> blocks;

  /// Parsed leading `---` block, or `null` when the document has none.
  final FrontMatter? frontMatter;

  /// Non-fatal problems encountered while parsing.
  ///
  /// Every one of these must degrade rather than throw (CLAUDE.md rule 9).
  final List<DocNotice> notices;

  /// Words in [sanitizedSource], fenced code excluded.
  ///
  /// Counted rather than split on whitespace, so Japanese does not report one
  /// word per paragraph — see `countWords`.
  final int wordCount;

  /// How many top-level ESM statements `MdxSanitizer` removed from an `.mdx`
  /// document, and zero for everything else.
  ///
  /// The one thing doc 04's placeholder spec asks for that a rewritten source
  /// string cannot carry. Every other transform becomes a fence or a code span
  /// and travels inside [sanitizedSource]; the header chip
  /// ("MDX · 3 imports hidden", ARB key `readerMdxImportsHidden`) is a count of
  /// text that is no longer there, so it has to travel beside it.
  final int mdxImportsHidden;
}

/// A top-level block of the source, located by line and character offset.
///
/// The `markdown` package's AST carries no source positions, so the pipeline
/// builds this index itself. It is what search hits and `#anchor` jumps aim
/// at — see `docs/04_MARKDOWN_PIPELINE.md`.
///
/// **Every position here indexes [DocModel.sanitizedSource]**, not the raw
/// file: that is the exact string the renderer parses, so it is the only one
/// whose offsets can line up with the widgets the reader scrolls to. The two
/// strings differ by the front matter and by any rewritten block HTML.
///
/// Blocks partition the source — consecutive blocks meet exactly, and the last
/// one runs to the end — so every offset falls inside exactly one block. The
/// one exception is the footnote section the parser synthesizes at the end of a
/// document with footnotes: it has no source of its own and spans nothing.
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
