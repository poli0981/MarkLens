/// The status bar along the bottom of the window: `path · position % · word
/// count · notices`, exactly the four fields `docs/06_UI_UX.md` specifies.
///
/// It replaces the S4 prototype line (`zoom … · sidebar … · outline … ·
/// theme …`), which was debug output that reached `main` and stayed there — a
/// live deviation from doc 06 and the only hardcoded English left in the shell
/// (CLAUDE.md rule 4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The bottom bar.
class StatusBar extends ConsumerWidget {
  /// Creates the status bar.
  const StatusBar({super.key});

  /// Separator between fields, as doc 06 draws it.
  static const String separator = '  ·  ';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeDocumentProvider);

    final style = theme.textTheme.bodySmall?.copyWith(color: tokens.fgMuted);
    final path = active.file?.path ?? active.failedPath;

    return Container(
      key: const Key('status-bar'),
      decoration: BoxDecoration(
        color: tokens.bgAlt,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: path == null
          ? Text(l10n.statusBarNoDocument, style: style)
          : Row(
              children: <Widget>[
                // The path takes the room the trailing fields do not: it is the
                // only field that can be arbitrarily long, and the only one
                // worth truncating. The full path stays reachable as a tooltip
                // rather than being lost to the ellipsis.
                Expanded(
                  child: Tooltip(
                    message: path,
                    child: Text(
                      path,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
                _Trailing(doc: active.doc, style: style),
              ],
            ),
    );
  }
}

/// Position, word count and notice count — the fields that never truncate.
class _Trailing extends ConsumerWidget {
  const _Trailing({required this.doc, required this.style});

  final DocModel? doc;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final document = doc;
    if (document == null) {
      // A file that could not be read has a path and nothing else to say
      // about it; the tab carries the explanation (`docs/07`).
      return const SizedBox.shrink();
    }

    // A `ValueListenableBuilder` rather than a watched provider: the position
    // changes as the wheel turns, and this rebuilds only this row — not the
    // path beside it, and nothing above it.
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: ValueListenableBuilder<int>(
        valueListenable: ref.watch(readerScrollProvider).positionPercent,
        builder: (context, percent, _) => Text(
          <String>[
            l10n.statusBarPosition(percent),
            l10n.statusBarWordCount(document.wordCount),
            if (document.notices.isNotEmpty)
              l10n.statusBarNotices(document.notices.length),
          ].join(StatusBar.separator),
          style: style,
        ),
      ),
    );
  }
}
