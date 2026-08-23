import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

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
  const FlutterMarkdownPlusRenderer({this.controller, this.onBlockCount});

  /// Scroll controller for the block list.
  final ScrollController? controller;

  /// Reports how many top-level blocks the renderer produced.
  ///
  /// Used by the S1 probe to check our own block index against what the
  /// renderer actually draws.
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
    return ListView.builder(
      controller: controller,
      itemCount: blocks.length,
      itemBuilder: (context, index) => blocks[index],
    );
  }
}

/// Images are never loaded during the bake-off: the policy in doc 04 replaces
/// remote and out-of-allowlist sources with placeholders anyway, and loading
/// real files would make the fidelity probe depend on disk state.
Widget _placeholderImage(Uri uri, String? title, String? alt) =>
    const SizedBox(width: 88, height: 20, child: Placeholder());
