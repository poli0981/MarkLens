import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart' as mw;
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

/// S1 candidate B — `markdown_widget`.
///
/// Its `MarkdownGenerator.buildWidgets` is the public equivalent of candidate
/// A's `MarkdownWidget.build(context, children)`: one whole-document parse in,
/// a list of top-level block widgets out. Both candidates therefore support the
/// per-block layout S1's second question asks about — which means that question
/// is not a discriminator between them.
class MarkdownWidgetRenderer implements MarkdownRenderer {
  /// Creates the candidate B renderer.
  const MarkdownWidgetRenderer({this.controller, this.onBlockCount});

  /// Scroll controller for the block list.
  final ScrollController? controller;

  /// Reports how many top-level blocks the renderer produced.
  final void Function(int count)? onBlockCount;

  @override
  Widget build(BuildContext context, DocModel doc) {
    final blocks = mw.MarkdownGenerator().buildWidgets(doc.sanitizedSource);
    onBlockCount?.call(blocks.length);
    return ListView.builder(
      controller: controller,
      itemCount: blocks.length,
      itemBuilder: (context, index) => blocks[index],
    );
  }
}
