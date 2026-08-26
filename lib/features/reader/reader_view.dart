import 'package:flutter/material.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/front_matter_panel.dart';
import 'package:marklens/features/reader/notice_bar.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';

/// The reading surface: notices, the front-matter panel, and the document.
///
/// Everything below the notice bar is the document; everything the renderer
/// draws comes from the doc 06 tokens by way of `ReaderStyle`, so a renderer
/// swap cannot change the app's typography (`docs/02_ARCHITECTURE.md`).
class ReaderView extends StatefulWidget {
  /// Creates a reader for [doc].
  const ReaderView({
    required this.doc,
    this.renderer = const FlutterMarkdownPlusRenderer(),
    this.frontMatterDisplay = FrontMatterDisplay.collapsed,
    this.contentMaxWidth = 760,
    this.zoom = 1,
    super.key,
  });

  /// The parsed document.
  final DocModel doc;

  /// The seam. Injected so a test can render without the real package.
  final MarkdownRenderer renderer;

  /// How the front-matter panel opens (`docs/05`).
  final FrontMatterDisplay frontMatterDisplay;

  /// Column width in logical pixels, or `0` for the full window.
  final double contentMaxWidth;

  /// Reading zoom, applied as a text scale.
  final double zoom;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  bool _noticesDismissed = false;

  @override
  void didUpdateWidget(ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new document gets its notices back. Dismissing a notice says "I have
    // read this one", not "stop telling me about documents".
    if (!identical(oldWidget.doc, widget.doc)) {
      _noticesDismissed = false;
    }
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
                        minScaleFactor: widget.zoom,
                        maxScaleFactor: widget.zoom,
                        child: widget.renderer.build(context, widget.doc),
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
