/// The heading tree beside the reader (`docs/06_UI_UX.md`, "Outline").
///
/// `Outline` and its GitHub slugs have been built by the pipeline since M1 and
/// consumed by nothing at all — the panel was a placeholder box with the word
/// "Outline" hardcoded in English. This is the panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/outline.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The outline panel.
class OutlinePanel extends ConsumerWidget {
  /// Creates the panel.
  const OutlinePanel({super.key});

  /// Row height. Fixed, so a thousand headings scroll without measuring.
  static const double rowExtent = 24;

  /// Indent per heading level.
  static const double indentPerLevel = 12;

  /// Deepest level that still indents.
  ///
  /// Beyond this the indent stops growing: six levels at full indent would
  /// push a `######` heading off a 200 px panel, and losing the text is worse
  /// than losing the depth.
  static const int maxIndentLevel = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final outline =
        ref.watch(
          activeDocumentProvider.select((state) => state.doc?.outline),
        ) ??
        Outline.empty;

    // No visible title row: 200 px is narrow, the headings say what this is,
    // and doc 06's layout diagram labels the panel the same way it labels
    // "Reader" — as a name for the region, not as chrome to draw. The name
    // survives as the screen-reader label, which is where doc 06's
    // accessibility section actually asks for it.
    return Semantics(
      container: true,
      label: l10n.outlinePanelTitle,
      child: Container(
        key: const Key('outline'),
        decoration: BoxDecoration(
          color: tokens.bgAlt,
          border: Border(left: BorderSide(color: tokens.border)),
        ),
        child: outline.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.outlineEmpty,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
                ),
              )
            : _Entries(
                outline: outline,
                scroller: ref.watch(readerScrollProvider),
              ),
      ),
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.outline, required this.scroller});

  final Outline outline;
  final BlockScroller scroller;

  @override
  Widget build(BuildContext context) {
    // Only this subtree rebuilds as the reader scrolls, and only when the
    // heading actually changes — not on every pixel, and nothing above it.
    return ValueListenableBuilder<int>(
      valueListenable: scroller.topBlock,
      builder: (context, topBlock, _) {
        final current = outline.headingAt(topBlock);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemExtent: OutlinePanel.rowExtent,
          itemCount: outline.entries.length,
          itemBuilder: (context, index) {
            final entry = outline.entries[index];
            return _Row(
              entry: entry,
              current: identical(entry, current),
              onTap: () => scroller.reveal(entry.blockIndex),
            );
          },
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.current,
    required this.onTap,
  });

  final OutlineEntry entry;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final depth = entry.level.clamp(1, OutlinePanel.maxIndentLevel) - 1;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 10 + depth * OutlinePanel.indentPerLevel,
          right: 10,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            entry.text,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              // The accent, which doc 06 reserves for links, focus rings and
              // the current outline entry — nothing else.
              color: current ? tokens.accent : tokens.fgMuted,
              fontWeight: current ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }
}
