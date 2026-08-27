/// The find bar over the reader (`docs/08_SEARCH.md`, "Find in file").
///
/// `features/search/` rather than `features/find/`: doc 02's target tree
/// reserves exactly that directory, and M3's cross-file search belongs beside
/// this rather than in a folder of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Query, case toggle, counter, and the two arrows.
class FindBar extends ConsumerStatefulWidget {
  /// Creates the bar.
  const FindBar({super.key});

  @override
  ConsumerState<FindBar> createState() => _FindBarState();
}

class _FindBarState extends ConsumerState<FindBar> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'find');

  @override
  void initState() {
    super.initState();
    _query.text = ref.read(findProvider).query;
    _field.requestFocus();
  }

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final find = ref.read(findProvider.notifier);
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      find.close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      // Enter and Shift+Enter cycle, which is why this is a key handler and
      // not `onSubmitted`: a text field reports neither the modifier nor a
      // second press of Enter on an unchanged query.
      HardwareKeyboard.instance.isShiftPressed ? find.previous() : find.next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(findProvider);
    final find = ref.read(findProvider.notifier);

    final counter = state.query.isEmpty
        ? ''
        : (state.hits.isEmpty
              ? l10n.findNoResults
              : l10n.findMatchCounter(state.current + 1, state.hits.length));

    return Focus(
      onKeyEvent: _onKey,
      child: Material(
        key: const Key('find-bar'),
        elevation: 4,
        color: tokens.bgAlt,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _query,
                  focusNode: _field,
                  autofocus: true,
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: l10n.findPlaceholder,
                  ),
                  onChanged: find.setQuery,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  counter,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.fgMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.findCaseSensitive,
                isSelected: state.caseSensitive,
                onPressed: find.toggleCase,
                icon: const Text('Aa'),
                iconSize: 13,
              ),
              IconButton(
                tooltip: l10n.findPrevious,
                onPressed: state.hits.isEmpty ? null : find.previous,
                icon: const Icon(Icons.keyboard_arrow_up),
                iconSize: 18,
              ),
              IconButton(
                tooltip: l10n.findNext,
                onPressed: state.hits.isEmpty ? null : find.next,
                icon: const Icon(Icons.keyboard_arrow_down),
                iconSize: 18,
              ),
              IconButton(
                tooltip: l10n.findClose,
                onPressed: find.close,
                icon: const Icon(Icons.close),
                iconSize: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
