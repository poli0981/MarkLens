import 'package:flutter/material.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Tells the reader that something about this document was not ordinary.
///
/// Four documents require a notice bar — CLAUDE.md rule 9, doc 00 principle 3,
/// doc 02's error philosophy and doc 04 stage 1 — and none of them said what it
/// looks like. Doc 06 mentioned notices only as an item in the status bar.
/// Decided here and written into doc 06:
///
/// - **A slim bar directly above the document**, not a line in the status bar.
///   `plainTextFallback` means the reader is looking at something that is not
///   the rendered document, and a person who misses that is being misled.
/// - **One notice at a time**, the most serious, with a count of the rest.
///   Stacking bars pushes the document down the screen, which is the thing the
///   reader actually came for.
/// - **Dismissible**, by its close button. A notice is information, not a
///   decision to make, and it must not be a permanent tax on the height of the
///   window. Dismissal lasts for that document: opening another brings its own
///   notices back.
///
/// The text comes from ARB (rule 4). `DocNotice` deliberately carries a kind
/// and never a message, so this is the only place any of them is phrased.
class NoticeBar extends StatelessWidget {
  /// Creates a notice bar for [notices].
  const NoticeBar({required this.notices, required this.onDismiss, super.key});

  /// Everything the pipeline reported about this document.
  final List<DocNotice> notices;

  /// Called by the close button.
  final VoidCallback onDismiss;

  /// Most serious first.
  ///
  /// The order is the order a reader needs to know things in: that the
  /// document is not really rendered, then that its bytes were not really
  /// text, then the merely notable.
  static const List<DocNoticeKind> severityOrder = <DocNoticeKind>[
    DocNoticeKind.plainTextFallback,
    DocNoticeKind.invalidUtf8,
    DocNoticeKind.mdxBailOut,
    DocNoticeKind.frontMatterUnparsed,
    DocNoticeKind.largeDocument,
  ];

  /// The notice to show, or `null` when there is nothing to say.
  static DocNotice? leadOf(List<DocNotice> notices) {
    for (final kind in severityOrder) {
      for (final notice in notices) {
        if (notice.kind == kind) {
          return notice;
        }
      }
    }
    return notices.isEmpty ? null : notices.first;
  }

  /// The message for [kind].
  ///
  /// Exhaustive with no default branch on purpose: adding a kind without a
  /// translation stops the build rather than showing a blank bar.
  static String messageFor(AppLocalizations l10n, DocNoticeKind kind) =>
      switch (kind) {
        DocNoticeKind.invalidUtf8 => l10n.readerNoticeInvalidUtf8,
        DocNoticeKind.frontMatterUnparsed =>
          l10n.readerNoticeFrontMatterUnparsed,
        DocNoticeKind.mdxBailOut => l10n.readerNoticeMdxBailOut,
        DocNoticeKind.plainTextFallback => l10n.readerNoticePlainTextFallback,
        DocNoticeKind.largeDocument => l10n.readerNoticeLargeDocument,
      };

  @override
  Widget build(BuildContext context) {
    final lead = leadOf(notices);
    if (lead == null) {
      return const SizedBox.shrink();
    }

    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final remaining = notices.length - 1;

    return Container(
      key: const Key('reader-notice-bar'),
      padding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: tokens.bgAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: tokens.fgMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: messageFor(l10n, lead.kind)),
                  if (lead.detail case final detail?)
                    TextSpan(
                      text: '  $detail',
                      style: TextStyle(color: tokens.fgMuted),
                    ),
                  if (remaining > 0)
                    TextSpan(
                      text: '  ·  ${l10n.readerNoticeMore(remaining)}',
                      style: TextStyle(color: tokens.fgMuted),
                    ),
                ],
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.readerNoticeDismiss,
            icon: Icon(Icons.close, color: tokens.fgMuted),
          ),
        ],
      ),
    );
  }
}
