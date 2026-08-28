import 'package:flutter/material.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/block_frame.dart';
import 'package:marklens/features/reader/front_matter_panel.dart';
import 'package:marklens/features/reader/notice_bar.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

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
    this.scroller,
    this.identity,
    this.restoreScroll = 0,
    this.rendererFactory = defaultRendererFactory,
    this.frontMatterDisplay = FrontMatterDisplay.collapsed,
    this.contentMaxWidth = 760,
    this.fontScale = 1,
    this.onLinkTap,
    super.key,
  });

  /// The parsed document.
  final DocModel doc;

  /// Where the reader is in the document, and how it gets somewhere else.
  ///
  /// Supplied by the shell in the running app; a reader pumped on its own in a
  /// test gets one of its own, so this widget stays testable without a
  /// provider scope.
  final BlockScroller? scroller;

  /// The open-set identity of [doc], for recording the scroll position.
  final String? identity;

  /// Where the session last saw this document, as a 0..1 ratio (doc 05).
  final double restoreScroll;

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

  /// Called with a tapped link's raw href (`docs/03_DATA_FLOW.md`).
  ///
  /// The reader raises the tap and decides nothing about it: routing needs the
  /// open set and the launcher, neither of which a feature may reach, so the
  /// shell hands `LinkRouter` down through here.
  final LinkTapCallback? onLinkTap;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  bool _noticesDismissed = false;

  /// The scroller this widget made for itself, if it was not given one.
  BlockScroller? _owned;

  BlockScroller get _scroller =>
      widget.scroller ?? (_owned ??= BlockScroller());

  @override
  void initState() {
    super.initState();
    _adopt();
  }

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.doc, widget.doc)) {
      // A new document gets its notices back. Dismissing a notice says "I have
      // read this one", not "stop telling me about documents".
      _noticesDismissed = false;
      _adopt();
      return;
    }

    // Same document, different shape. Every measured offset described the old
    // layout, and an estimate built from stale anchors lands nowhere.
    if (oldWidget.fontScale != widget.fontScale ||
        oldWidget.contentMaxWidth != widget.contentMaxWidth ||
        oldWidget.frontMatterDisplay != widget.frontMatterDisplay) {
      _scroller.invalidateMeasurements();
    }
  }

  void _adopt() => _scroller.adopt(
    identity: widget.identity ?? widget.doc.path,
    blockCount: widget.doc.blocks.length,
    restoreRatio: widget.restoreScroll,
  );

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final frontMatter = widget.doc.frontMatter;
    final scroller = _scroller;

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
                  // Doc 04's MDX transform 1: the statements are gone from the
                  // flow, and the chip is the only thing that says so. It sits
                  // above the front-matter panel because both are document
                  // header rather than document.
                  if (widget.doc.mdxImportsHidden > 0)
                    _MdxChip(count: widget.doc.mdxImportsHidden),
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
                            .rendererFactory(scroller.controller)
                            .build(
                              context,
                              widget.doc,
                              wrapBlock: (index, child) => BlockFrame(
                                index: index,
                                scroller: scroller,
                                child: child,
                              ),
                              onLinkTap: widget.onLinkTap,
                            ),
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

/// "MDX · 3 imports hidden" — the one thing `MdxSanitizer` removes that leaves
/// no trace in the document (`docs/04_MARKDOWN_PIPELINE.md`, transform 1).
///
/// A chip rather than a notice: nothing went wrong, and doc 06's notice bar
/// shows one problem at a time with the rest counted. Hiding ESM statements is
/// the feature working.
class _MdxChip extends StatelessWidget {
  const _MdxChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.bgAlt,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          AppLocalizations.of(context).readerMdxImportsHidden(count),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: tokens.fgMuted),
        ),
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
