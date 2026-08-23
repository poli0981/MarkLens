import 'dart:convert';

import 'package:marklens/core/markdown/block_index.dart';
import 'package:marklens/core/markdown/front_matter.dart';
import 'package:marklens/core/markdown/mdx_sanitizer.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/outline.dart';

/// The one path from a file's bytes to a [DocModel].
///
/// ```text
/// bytes → decode → front-matter split → [mdx sanitize] → parse → DocModel
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
    this.blockIndexer = const BlockIndexer(),
  });

  /// Lifts the leading `---` block out before anything else sees it.
  final FrontMatterSplitter frontMatterSplitter;

  /// Turns JSX into inert placeholders, for `.mdx` files only.
  final MdxSanitizer mdxSanitizer;

  /// Locates top-level blocks so search hits and anchors have a target.
  final BlockIndexer blockIndexer;

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

    final decoded = decodeSource(bytes);
    if (decoded.lossy) {
      notices.add(const DocNotice(DocNoticeKind.invalidUtf8));
    }

    final split = frontMatterSplitter.split(decoded.text);
    if (split.frontMatter != null && !split.frontMatter!.parsed) {
      notices.add(const DocNotice(DocNoticeKind.frontMatterUnparsed));
    }

    var source = split.body;
    if (isMdx) {
      final sanitized = mdxSanitizer.sanitize(source);
      source = sanitized.source;
      notices.addAll(sanitized.notices);
    }

    // Parsing into an AST, and extracting the outline from it, lands at M2
    // (doc 15). Until then the renderer still receives correct source; only
    // the outline panel and anchor jumps are empty.
    return DocModel(
      path: path,
      sanitizedSource: source,
      outline: Outline.empty,
      blocks: blockIndexer.index(source),
      frontMatter: split.frontMatter,
      notices: notices,
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
