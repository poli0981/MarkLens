import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/search/search_service.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Search across the open files (`docs/08_SEARCH.md`, `Ctrl+Shift+F`).
///
/// It replaces the sidebar rather than joining it, which is doc 06's
/// one-column-of-context rule: the reader is the point, and two stacked lists
/// beside it is two things competing to be read.
///
/// The rows are flat — a file header followed by its hits — rather than a tree
/// of expandable groups. A result list you have to open to read is a result
/// list that hides the answer, and the whole reason this exists is that the tab
/// strip cannot show a thousand files.
class SearchPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  late final TextEditingController _query = TextEditingController(
    text: ref.read(crossSearchProvider).query,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'cross-search');

  @override
  void initState() {
    super.initState();
    // Opening the panel and then having to click into it would make
    // `Ctrl+Shift+F` two gestures instead of one.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    ref.read(crossSearchProvider.notifier).clear();
    ref.read(chromeProvider.notifier).showFiles();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = ReaderTokens.of(context);
    final state = ref.watch(crossSearchProvider);
    final controller = ref.read(crossSearchProvider.notifier);

    return ColoredBox(
      color: tokens.bgAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    onChanged: controller.setQuery,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.searchAcrossHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.toggleCase,
                  isSelected: state.caseSensitive,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.findCaseSensitive,
                  icon: const Text('Aa', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  onPressed: _close,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.searchAcrossClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: _Summary(state: state),
          ),
          const Divider(height: 1),
          Expanded(child: _Results(state: state)),
        ],
      ),
    );
  }
}

/// "12 matches in 3 files", or why there are none.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final CrossSearchState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = ReaderTokens.of(context);
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: tokens.fgMuted);

    final text = switch (state) {
      CrossSearchState(query: '') => '',
      CrossSearchState(running: true) => l10n.searchAcrossRunning,
      CrossSearchState(results: []) => l10n.searchAcrossNoMatches,
      _ => l10n.searchAcrossSummary(state.matchCount, state.results.length),
    };
    return Text(text, style: style);
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.state});

  final CrossSearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flattened once per result set rather than per frame: the list is
    // virtualized (doc 06 wants a thousand entries to scroll cold), and a
    // builder that walked a nested structure to find row *n* would be doing
    // that work for every row on every frame.
    final rows = <_Row>[
      for (final file in state.results) ...<_Row>[
        _Row.file(file),
        for (var i = 0; i < file.hits.length; i++) _Row.hit(file, i),
      ],
    ];

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index].build(context, ref),
    );
  }
}

/// One line in the flattened result list: a file header, or one of its hits.
class _Row {
  const _Row.file(this.file) : hitIndex = -1;
  const _Row.hit(this.file, this.hitIndex);

  final FileHits file;
  final int hitIndex;

  bool get isHeader => hitIndex < 0;

  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
        child: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                ExtensionRegistry.basenameOf(file.path),
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              file.truncated
                  // Never a silent cap: a panel that shows fifty of nine
                  // thousand without saying so is lying about the document.
                  ? l10n.searchAcrossTruncated(file.hits.length)
                  : '${file.hits.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.fgMuted,
              ),
            ),
          ],
        ),
      );
    }

    final hit = file.hits[hitIndex];
    return InkWell(
      onTap: () => ref
          .read(crossSearchProvider.notifier)
          .reveal(path: file.path, hitIndex: hitIndex),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 3, 10, 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                '${hit.line + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.fgMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                hit.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
