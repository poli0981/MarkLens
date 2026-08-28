import 'dart:convert';

import 'package:marklens/core/markdown/block_index.dart';
import 'package:marklens/core/markdown/front_matter.dart';
import 'package:marklens/core/markdown/mdx_sanitizer.dart';
import 'package:marklens/core/markdown/outline_builder.dart';
import 'package:marklens/core/markdown/raw_block_rewriter.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/outline.dart';

/// The one path from a file's bytes to a [DocModel].
///
/// ```text
/// bytes → decode → front-matter split → [mdx sanitize] → rewrite block HTML
///       → parse → DocModel (blocks · outline · slugs)
/// ```
///
/// Every stage is pure Dart (CLAUDE.md rule 3) and every stage degrades
/// instead of throwing (rule 9). The pipeline stops at a [DocModel];
/// `MarkdownRenderer` in `features/reader/rendering/` turns that into widgets.
/// See `docs/02_ARCHITECTURE.md`, "The seam".
class MarkdownPipeline {
  /// Creates a pipeline from its stages.
  const MarkdownPipeline({
    this.frontMatterSplitter = const FrontMatterSplitter(),
    this.mdxSanitizer = const MdxSanitizer(),
    this.rawBlockRewriter = const RawBlockRewriter(),
    this.blockIndexer = const BlockIndexer(),
    this.outlineBuilder = const OutlineBuilder(),
    this.largeDocumentBytes = defaultLargeDocumentBytes,
  });

  /// The doc 04 threshold above which a document is flagged as large.
  ///
  /// Refusing outright above 50 MB belongs to the file service, which decides
  /// whether to open a file at all; by the time bytes reach the pipeline that
  /// decision has been made.
  static const int defaultLargeDocumentBytes = 10 * 1024 * 1024;

  /// The size above which this pipeline flags a document as large.
  ///
  /// Injected rather than fixed so tests can exercise the boundary without
  /// parsing ten megabytes to reach it.
  final int largeDocumentBytes;

  /// Lifts the leading `---` block out before anything else sees it.
  final FrontMatterSplitter frontMatterSplitter;

  /// Turns JSX into inert placeholders, for `.mdx` files only.
  final MdxSanitizer mdxSanitizer;

  /// Rescues block HTML, which the renderer would otherwise delete.
  final RawBlockRewriter rawBlockRewriter;

  /// Locates top-level blocks so search hits and anchors have a target.
  final BlockIndexer blockIndexer;

  /// Collects the headings, with their slugs.
  final OutlineBuilder outlineBuilder;

  /// Parses one document.
  ///
  /// [isMdx] is decided by file extension alone — never by sniffing content
  /// (`docs/04_MARKDOWN_PIPELINE.md`).
  DocModel parse({
    required String path,
    required List<int> bytes,
    required bool isMdx,
  }) {
    final notices = <DocNotice>[];

    if (bytes.length > largeDocumentBytes) {
      notices.add(const DocNotice(DocNoticeKind.largeDocument));
    }

    final decoded = decodeSource(bytes);
    if (decoded.lossy) {
      notices.add(const DocNotice(DocNoticeKind.invalidUtf8));
    }

    final split = frontMatterSplitter.split(decoded.text);
    if (split.frontMatter != null && !split.frontMatter!.parsed) {
      notices.add(const DocNotice(DocNoticeKind.frontMatterUnparsed));
    }

    var source = split.body;
    var mdxImportsHidden = 0;
    if (isMdx) {
      final sanitized = mdxSanitizer.sanitize(source);
      source = sanitized.source;
      notices.addAll(sanitized.notices);
      mdxImportsHidden = sanitized.esmRemoved;
    }

    // Block HTML is rewritten before the index is built, not after. While it
    // is still a bare text node the renderer emits no widget for it at all, so
    // our block count would run one ahead of the renderer's for every region
    // (`docs/spike-results/S1-renderer-bakeoff.md`, Result 3).
    source = rawBlockRewriter.rewrite(source).source;

    final index = blockIndexer.index(source);
    if (index.degraded) {
      // Rule 9: show the document as plain text with a notice, rather than
      // taking the app down or — worse — offering scroll targets that are
      // quietly wrong.
      notices.add(const DocNotice(DocNoticeKind.plainTextFallback));
      return DocModel(
        path: path,
        rawSource: decoded.text,
        sanitizedSource: source,
        outline: Outline.empty,
        blocks: const <SourceBlock>[],
        frontMatter: split.frontMatter,
        notices: notices,
        mdxImportsHidden: mdxImportsHidden,
      );
    }

    return DocModel(
      path: path,
      rawSource: decoded.text,
      sanitizedSource: source,
      outline: outlineBuilder.build(index.nodes),
      blocks: index.blocks,
      frontMatter: split.frontMatter,
      notices: notices,
      mdxImportsHidden: mdxImportsHidden,
    );
  }

  /// Decodes [bytes] as UTF-8, stripping a byte-order mark if present.
  ///
  /// Invalid sequences decode lossily to U+FFFD rather than throwing, and the
  /// caller is told so it can raise a notice bar (CLAUDE.md rule 9). A
  /// zero-byte file decodes to an empty document, which is not an error
  /// (`docs/07_FILES_AND_WATCH.md`).
  static ({String text, bool lossy}) decodeSource(List<int> bytes) {
    final data = _hasUtf8Bom(bytes) ? bytes.sublist(3) : bytes;
    try {
      return (text: utf8.decode(data), lossy: false);
    } on FormatException {
      return (text: utf8.decode(data, allowMalformed: true), lossy: true);
    }
  }

  static bool _hasUtf8Bom(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
}
