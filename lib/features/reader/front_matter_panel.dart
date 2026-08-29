import 'package:flutter/material.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Shows a document's leading `---` block, which never reaches the renderer.
///
/// Doc 04 stage 2: a collapsible key/value panel, with the setting choosing
/// whether it starts collapsed, expanded or hidden. A block that did not parse
/// as simple `key: value` lines is shown exactly as written — throwing away
/// the user's text to report an error is worse than showing it.
class FrontMatterPanel extends StatefulWidget {
  /// Creates a panel for [frontMatter].
  const FrontMatterPanel({
    required this.frontMatter,
    this.display = FrontMatterDisplay.collapsed,
    super.key,
  });

  /// The parsed block.
  final FrontMatter frontMatter;

  /// How the panel opens (`docs/05_SESSION_AND_SETTINGS.md`).
  final FrontMatterDisplay display;

  @override
  State<FrontMatterPanel> createState() => _FrontMatterPanelState();
}

class _FrontMatterPanelState extends State<FrontMatterPanel> {
  late bool _expanded = widget.display == FrontMatterDisplay.expanded;

  @override
  void didUpdateWidget(FrontMatterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The setting changing is an instruction; a rebuild for any other reason is
    // not. Re-syncing only when `display` actually moved is what lets someone
    // collapse the panel by hand and keep it collapsed, while still having
    // `reading.frontMatter` mean something once it can be changed at all
    // (`docs/05_SESSION_AND_SETTINGS.md`).
    if (oldWidget.display != widget.display) {
      _expanded = widget.display == FrontMatterDisplay.expanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.display == FrontMatterDisplay.hidden) {
      return const SizedBox.shrink();
    }

    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      key: const Key('reader-front-matter'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: tokens.bgAlt,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: tokens.fgMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.readerFrontMatterTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.fgMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.frontMatter.parsed
                  ? _Fields(fields: widget.frontMatter.fields)
                  : _Raw(raw: widget.frontMatter.raw),
            ),
        ],
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields({required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        children: <TableRow>[
          for (final entry in fields.entries)
            TableRow(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 4),
                  child: Text(
                    entry.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.fgMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.fg,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Raw extends StatelessWidget {
  const _Raw({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    return SelectionArea(
      child: Text(
        raw,
        style: TextStyle(
          fontFamily: monoFamily,
          fontFamilyFallback: monoFallback,
          fontSize: 13,
          height: 1.45,
          color: tokens.fg,
        ),
      ),
    );
  }
}
