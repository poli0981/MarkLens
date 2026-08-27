import 'package:flutter/material.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/front_matter_panel.dart';
import 'package:marklens/features/reader/notice_bar.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

/// The renderer the app actually reads with, wired to the reader's controller.
///
/// A named top-level function rather than a closure so it can be a `const`
/// default argument.
MarkdownRenderer defaultRendererFactory(ScrollController controller) =>
    FlutterMarkdownPlusRenderer(controller: controller);

/// The reading surface: notices, the front-matter panel, and the document.
///
/// Everything below the notice bar is the document; everything the renderer
/// draws comes from the doc 06 tokens by way of `ReaderStyle`, so a renderer
/// swap cannot change the app's typography (`docs/02_ARCHITECTURE.md`).
class ReaderView extends StatefulWidget {
  /// Creates a reader for [doc].
  const ReaderView({
    required this.doc,
    this.rendererFactory = defaultRendererFactory,
    this.frontMatterDisplay = FrontMatterDisplay.collapsed,
    this.contentMaxWidth = 760,
    this.fontScale = 1,
    this.onPosition,
    super.key,
  });

  /// The parsed document.
  final DocModel doc;

  /// The seam. Injected so a test can render without the real package.
  ///
  /// A factory rather than a renderer, because the reader owns the scroll
  /// controller and the renderer needs it: the document's scroll view lives
  /// inside the renderer (that is what makes blocks lazy), while everything
  /// that wants to *drive* it — the status bar's position, session restore,
  /// outline jumps — lives outside. The same shape
  /// `integration_test/perf_gate_test.dart` already uses, so the
  /// `MarkdownRenderer` interface itself is untouched (CLAUDE.md rule 6).
  final MarkdownRenderer Function(ScrollController controller) rendererFactory;

  /// Called with how far through the document the reader is, as a 0..1 ratio.
  ///
  /// Fires only when the whole percent changes, not on every scroll tick: the
  /// status bar shows a percentage, so finer reporting would rebuild it sixty
  /// times a second to display the same string (CLAUDE.md rule 7).
  final ValueChanged<double>? onPosition;

  /// How the front-matter panel opens (`docs/05`).
  final FrontMatterDisplay frontMatterDisplay;

  /// Column width in logical pixels, or `0` for the full window.
  final double contentMaxWidth;

  /// The reading scale, 0.5–3.0 (`reading.fontScale`, doc 05).
  ///
  /// Applied *clamped* rather than multiplied, so Reset Zoom means exactly
  /// 100% and the platform's own text scale is deliberately not compounded on
  /// top of the user's choice.
  final double fontScale;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  bool _noticesDismissed = false;

  final ScrollController _scroll = ScrollController();

  /// The last whole percent reported, so identical values are not re-sent.
  int _percent = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_reportPosition);
  }

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.doc, widget.doc)) {
      // A new document gets its notices back. Dismissing a notice says "I have
      // read this one", not "stop telling me about documents".
      _noticesDismissed = false;
      // And it starts at the top. Without this the list keeps the offset of
      // the document that was showing a moment ago, because the state — and
      // so the controller — survives a tab switch.
      _resetToTop = true;
      _schedulePositionReport();
    }
  }

  void _reportPosition() => _schedulePositionReport();

  /// Whether the next report should first put the list back at the top.
  bool _resetToTop = false;

  /// Whether a report is already queued for the end of this frame.
  bool _reportPending = false;

  /// Reports the position after the frame, never during it.
  ///
  /// The listener fires while the scroll view is laying out — and it fires for
  /// the first time as the position attaches, before anything has been
  /// scrolled at all. Telling a provider about it there is a state change
  /// during build, which Flutter tears the widget tree down over. Once per
  /// frame at the end of it is both safe and finer resolution than a status
  /// bar showing whole percents can use.
  void _schedulePositionReport() {
    if (_reportPending) {
      return;
    }
    _reportPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportPending = false;
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      if (_resetToTop) {
        _resetToTop = false;
        _scroll.jumpTo(0);
      }
      final extent = _scroll.position.maxScrollExtent;
      // A document shorter than the viewport does not scroll, and dividing by
      // its zero extent would report NaN rather than "at the top".
      final ratio = extent <= 0
          ? 0.0
          : (_scroll.offset / extent).clamp(0.0, 1.0);
      final percent = (ratio * 100).round();
      if (percent == _percent) {
        return;
      }
      _percent = percent;
      widget.onPosition?.call(ratio);
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_reportPosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final frontMatter = widget.doc.frontMatter;

    return ColoredBox(
      color: tokens.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_noticesDismissed && widget.doc.notices.isNotEmpty)
            NoticeBar(
              notices: widget.doc.notices,
              onDismiss: () => setState(() => _noticesDismissed = true),
            ),
          Expanded(
            child: _Column(
              maxWidth: widget.contentMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (frontMatter != null)
                    // Above the document rather than scrolling with it. The
                    // renderer owns its own scroll view — that is what makes
                    // blocks lazy (S2) — so a header inside it would mean
                    // changing the seam. Collapsed by default, it costs one
                    // row; expanded, it is capped so it cannot swallow the
                    // window.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: FrontMatterPanel(
                          frontMatter: frontMatter,
                          display: widget.frontMatterDisplay,
                        ),
                      ),
                    ),
                  Expanded(
                    // One selection scope for the whole document, so a drag
                    // crosses headings, paragraphs, code blocks and table
                    // cells in one go (`docs/spike-results/S2-selection.md`).
                    // It reaches only what has been built — blocks are lazy —
                    // which is why File -> Copy entire document exists
                    // alongside it (`docs/06_UI_UX.md`).
                    child: SelectionArea(
                      child: MediaQuery.withClampedTextScaling(
                        minScaleFactor: widget.fontScale,
                        maxScaleFactor: widget.fontScale,
                        child: widget
                            .rendererFactory(_scroll)
                            .build(context, widget.doc),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Constrains the reading column, or lets it fill the window when the setting
/// says zero (`docs/05_SESSION_AND_SETTINGS.md`).
class _Column extends StatelessWidget {
  const _Column({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (maxWidth <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: child,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: child,
        ),
      ),
    );
  }
}
