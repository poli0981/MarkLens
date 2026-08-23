import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

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
/// - **It emits nothing at all for block HTML.** The "Raw HTML (not rendered)"
///   box in `docs/04_MARKDOWN_PIPELINE.md` has to be produced upstream, in
///   `core/markdown/`, before the renderer ever sees the document.
class FlutterMarkdownPlusRenderer implements MarkdownRenderer {
  /// Creates the reader renderer.
  const FlutterMarkdownPlusRenderer({this.controller, this.onBlockCount});

  /// Scroll controller for the block list.
  final ScrollController? controller;

  /// Reports how many entries the renderer produced, spacers included.
  ///
  /// Used by the performance gate and the block-mapping regression tests.
  final void Function(int count)? onBlockCount;

  @override
  Widget build(BuildContext context, DocModel doc) => _BlockListMarkdown(
    data: doc.sanitizedSource,
    controller: controller,
    onBlockCount: onBlockCount,
  );
}

class _BlockListMarkdown extends MarkdownWidget {
  const _BlockListMarkdown({
    required super.data,
    this.controller,
    this.onBlockCount,
  }) : super(imageBuilder: _placeholderImage, extensionSet: null);

  final ScrollController? controller;
  final void Function(int count)? onBlockCount;

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
    return ListView.builder(
      controller: controller,
      itemCount: blocks.length,
      itemBuilder: (context, index) => blocks[index],
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
