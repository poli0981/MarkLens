import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/markdown/markdown_flavor.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/code_block_builder.dart';
import 'package:marklens/features/reader/rendering/code_highlighter.dart';
import 'package:marklens/features/reader/rendering/highlight_js_code_highlighter.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';
import 'package:marklens/features/reader/rendering/reader_style.dart';

/// The reader, built on `flutter_markdown_plus` — the S1 winner
/// (`docs/spike-results/S1-renderer-bakeoff.md`).
///
/// The interesting part is [_BlockListMarkdown]. `MarkdownWidget` hands its
/// subclass the finished list of **top-level block widgets** and lets the
/// subclass decide the layout, which is what gives us per-block widgets to
/// scroll to *without* parsing each block in isolation — an isolated block
/// cannot see a reference-link or footnote definition that lives elsewhere in
/// the document (measured in S1).
///
/// Two behaviours of the package are load-bearing and easy to break:
///
/// - **Its child list is `2N-1`**: a `SizedBox` spacer sits between every pair
///   of real blocks. Recovering the block list by dropping `SizedBox`es is
///   *not* safe, because an empty heading is a real block that also renders as
///   one. Index arithmetic (`sourceBlock[i] -> children[2i]`) is the only
///   correct mapping.
/// - **It emits nothing at all for block HTML.** The content is deleted, not
///   escaped, so `RawBlockRewriter` in `core/markdown/` rewrites every region
///   into a fenced block before the document reaches here. That is also what
///   keeps the `2N-1` arithmetic above true: a root-level text node is one
///   block to us and zero children to the renderer.
class FlutterMarkdownPlusRenderer implements MarkdownRenderer {
  /// Creates the reader renderer.
  const FlutterMarkdownPlusRenderer({
    this.controller,
    this.onBlockCount,
    this.highlighter,
  });

  /// Scroll controller for the block list.
  final ScrollController? controller;

  /// Reports how many entries the renderer produced, spacers included.
  ///
  /// Used by the performance gate and the block-mapping regression tests.
  final void Function(int count)? onBlockCount;

  /// Colours fenced code.
  ///
  /// Built from the theme tokens when omitted, which is the normal case; a
  /// test can inject one to render without depending on a grammar.
  final CodeHighlighter? highlighter;

  @override
  Widget build(
    BuildContext context,
    DocModel doc, {
    BlockWrapper? wrapBlock,
  }) => _BlockListMarkdown(
    data: doc.sanitizedSource,
    controller: controller,
    onBlockCount: onBlockCount,
    wrapBlock: wrapBlock,
    styleSheet: ReaderStyle.of(context),
    codeBlocks: CodeBlockBuilder(
      highlighter: highlighter ?? _highlighterFor(context),
    ),
  );

  /// The default highlighter: scopes painted from the doc 06 tokens.
  static CodeHighlighter _highlighterFor(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    return HighlightJsCodeHighlighter(
      theme: ReaderCodeTheme.of(tokens),
      baseStyle: TextStyle(color: tokens.fg),
    );
  }
}

class _BlockListMarkdown extends MarkdownWidget {
  // Not const: `markdownExtensionSet` cannot be, because the package builds
  // `ExtensionSet.gitHubFlavored` as a static final. Naming the set is worth
  // more than a const constructor on one private widget.
  _BlockListMarkdown({
    required super.data,
    required CodeBlockBuilder codeBlocks,
    required super.styleSheet,
    this.controller,
    this.onBlockCount,
    this.wrapBlock,
  }) : super(
         // Every `pre` is drawn by our own builder: fenced code gets a
         // language label and a copy button, and a block the raw-HTML rewrite
         // produced gets the collapsed "Raw HTML (not rendered)" box instead
         // (`docs/04_MARKDOWN_PIPELINE.md`).
         builders: <String, MarkdownElementBuilder>{'pre': codeBlocks},
         imageBuilder: _placeholderImage,
         // Named, not left to the package's `?? gitHubFlavored` fallback: the
         // pipeline parses the same source with the same set to build the
         // block index, and a silent divergence here would break every anchor
         // jump. One constant, read by both sides.
         extensionSet: markdownExtensionSet,
       );

  final ScrollController? controller;
  final void Function(int count)? onBlockCount;
  final BlockWrapper? wrapBlock;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    final blocks = children ?? const <Widget>[];
    onBlockCount?.call(blocks.length);

    // Lazy, deliberately. S2 measured the alternative: building every block up
    // front so the whole document sits inside one SelectionArea costs 527 ms
    // to first paint on a *typical* 100 KB document — three and a half times
    // the charter budget — and kills the process outright at 1 MB. Whole
    // document selection was replaced by File -> Copy entire document instead
    // (docs/06_UI_UX.md, docs/spike-results/S2-selection.md).
    final wrap = wrapBlock;
    return ListView.builder(
      controller: controller,
      itemCount: blocks.length,
      // `children[2i]` is block `i`; the odd entries are the package's spacers
      // and belong to nobody. Halving the index here is the one place in the
      // codebase that has to know that, which is the point of doing it here
      // rather than making every caller carry the arithmetic.
      itemBuilder: (context, index) => wrap == null || index.isOdd
          ? blocks[index]
          : wrap(index ~/ 2, blocks[index]),
    );
  }
}

/// Images are resolved by the reader's own policy (`docs/04`), never by the
/// renderer package: local only by default, extension-checked and size-capped,
/// with remote sources shown as a blocked placeholder. Until that lands, every
/// image is a placeholder — which is also what keeps tests independent of disk
/// state.
Widget _placeholderImage(Uri uri, String? title, String? alt) =>
    const SizedBox(width: 88, height: 20, child: Placeholder());
