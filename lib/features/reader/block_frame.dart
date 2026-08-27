import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';

/// One top-level block, measured and — when it has just been jumped to —
/// pulsed.
///
/// This is what `MarkdownRenderer.build`'s `wrapBlock` returns, so it is the
/// point where a block stops being an anonymous list child and becomes
/// something the outline, the find bar and the session can all address by
/// index.
///
/// **Measured on build, never on scroll.** `ListView` does not rebuild its
/// children while the wheel turns, so the cost here is paid once per block per
/// layout and nothing at all per frame — which is what keeps the doc 00 scroll
/// budget intact.
class BlockFrame extends StatefulWidget {
  /// Wraps [child], the widget the renderer produced for block [index].
  const BlockFrame({
    required this.index,
    required this.scroller,
    required this.child,
    super.key,
  });

  /// Position in `DocModel.blocks`.
  final int index;

  /// Where the measurement goes.
  final BlockScroller scroller;

  /// The rendered block.
  final Widget child;

  @override
  State<BlockFrame> createState() => _BlockFrameState();
}

class _BlockFrameState extends State<BlockFrame> {
  @override
  void initState() {
    super.initState();
    _measureAfterLayout();
  }

  @override
  void didUpdateWidget(BlockFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measureAfterLayout();
  }

  @override
  void dispose() {
    widget.scroller.forgetIfPresent(widget.index);
    super.dispose();
  }

  void _measureAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        return;
      }
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) {
        return;
      }
      // The exact scroll offset that would put this box at the leading edge —
      // no estimating, for any block that has actually been laid out.
      widget.scroller.report(
        widget.index,
        viewport.getOffsetToReveal(box, 0).offset,
        box.size.height,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: widget.scroller.pulsingBlock,
      builder: (context, pulsing, child) {
        final active = pulsing == widget.index;
        return AnimatedContainer(
          duration: BlockScroller.pulseDuration ~/ 3,
          // The accent, at the weight doc 06 reserves for it: a pulse that
          // says "here", not a highlight that competes with the text.
          color: active ? tokens.accent.withValues(alpha: 0.14) : null,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
