import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

/// How the reader lays its block widgets out.
///
/// S2 exists because these two are not interchangeable: a lazily built child
/// that has not been built cannot be selected, so whole-document selection
/// (`docs/06_UI_UX.md`) and block-laziness (`docs/04_MARKDOWN_PIPELINE.md`)
/// pull against each other. This enum is what lets the spike measure both
/// rather than argue about them.
enum ReaderLayout {
  /// `ListView.builder` — only the blocks near the viewport are built.
  lazyList,

  /// Every block built up front inside a scroll view.
  ///
  /// Costs first paint, but the whole document exists in the widget tree and
  /// is therefore selectable.
  eagerColumn,
}

/// S1 candidate A — `flutter_markdown_plus`.
///
/// The interesting part is [_BlockListMarkdown]. `MarkdownWidget` hands its
/// subclass the finished list of **top-level block widgets** and lets the
/// subclass decide the layout, which is what resolves S1's second structural
/// question: we get per-block widgets to scroll to *without* parsing each block
/// in isolation, so reference links and footnotes defined elsewhere in the
/// document still resolve.
class FlutterMarkdownPlusRenderer implements MarkdownRenderer {
  /// Creates the candidate A renderer.
  const FlutterMarkdownPlusRenderer({
    this.controller,
    this.onBlockCount,
    this.layout = ReaderLayout.lazyList,
  });

  /// Scroll controller for the block list.
  final ScrollController? controller;

  /// Reports how many top-level blocks the renderer produced.
  ///
  /// Used by the S1 probe to check our own block index against what the
  /// renderer actually draws.
  final void Function(int count)? onBlockCount;

  /// Whether blocks are built lazily or all at once. See [ReaderLayout].
  final ReaderLayout layout;

  @override
  Widget build(BuildContext context, DocModel doc) => _BlockListMarkdown(
    data: doc.sanitizedSource,
    controller: controller,
    onBlockCount: onBlockCount,
    layout: layout,
  );
}

/// Candidate A in its own `selectable` mode, for comparison against wrapping
/// our block list in a `SelectionArea` (doc 15, S2).
class NativeSelectableMarkdown extends StatelessWidget {
  /// Creates the native-selection variant.
  const NativeSelectableMarkdown({required this.doc, super.key});

  /// The document to render.
  final DocModel doc;

  @override
  Widget build(BuildContext context) => Markdown(
    data: doc.sanitizedSource,
    selectable: true,
    imageBuilder: _placeholderImage,
  );
}

class _BlockListMarkdown extends MarkdownWidget {
  const _BlockListMarkdown({
    required super.data,
    required this.layout,
    this.controller,
    this.onBlockCount,
  }) : super(imageBuilder: _placeholderImage, extensionSet: null);

  final ScrollController? controller;
  final void Function(int count)? onBlockCount;
  final ReaderLayout layout;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    final blocks = children ?? const <Widget>[];
    onBlockCount?.call(blocks.length);

    return switch (layout) {
      ReaderLayout.lazyList => ListView.builder(
        controller: controller,
        itemCount: blocks.length,
        itemBuilder: (context, index) => blocks[index],
      ),
      ReaderLayout.eagerColumn => SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: blocks,
        ),
      ),
    };
  }
}

/// Images are never loaded during the bake-off: the policy in doc 04 replaces
/// remote and out-of-allowlist sources with placeholders anyway, and loading
/// real files would make the fidelity probe depend on disk state.
Widget _placeholderImage(Uri uri, String? title, String? alt) =>
    const SizedBox(width: 88, height: 20, child: Placeholder());
