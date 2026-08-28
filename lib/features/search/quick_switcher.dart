import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/search/fuzzy.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// One row in the switcher.
typedef SwitcherEntry = ({String path, String name, String folder, bool open});

/// The quick switcher (`docs/08_SEARCH.md`, `Ctrl+P`).
///
/// Doc 08 is explicit about what this is for: "the intended navigation for a
/// 1,000-entry session — the tab strip is for the working few, `Ctrl+P` is for
/// everything". So it lists the open set *and* the recent list, and ranks both
/// by the same fuzzy score over name and relative path.
///
/// An overlay rather than a panel: it is a thing you pass through, not a thing
/// you keep open, and it must not move the document underneath it.
class QuickSwitcher extends ConsumerStatefulWidget {
  /// Creates the switcher.
  const QuickSwitcher({super.key});

  /// Shows it over [context] and activates whatever is chosen.
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (context) => const QuickSwitcher(),
  );

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _list = ScrollController();

  /// The key handler lives on the field's **own** focus node, not on an
  /// ancestor `Focus` or `Shortcuts`.
  ///
  /// Flutter dispatches a key to the focused node's handler first and only
  /// then walks up the focus chain — and `EditableText`'s arrow-key handling
  /// is an ancestor `Shortcuts` widget. An ancestor handler therefore never
  /// sees an arrow key at all: the caret moves instead of the selection, which
  /// is exactly what a switcher must not do.
  late final FocusNode _field = FocusNode(
    debugLabel: 'quick-switcher',
    onKeyEvent: (node, event) => _onKey(_rows, event),
  );

  /// The rows the last build produced, so the key handler can act on them.
  List<SwitcherEntry> _rows = const <SwitcherEntry>[];

  /// Row height, so keyboard selection can scroll to a row it cannot see.
  static const double rowExtent = 44;

  int _selected = 0;

  @override
  void dispose() {
    _query.dispose();
    _field.dispose();
    _list.dispose();
    super.dispose();
  }

  /// Everything the switcher can offer, before the query narrows it.
  ///
  /// Open files first, in most-recently-used order, then anything in the
  /// recent list that is not already open. A file appears once: it is either
  /// something you have, or something you had.
  List<SwitcherEntry> _candidates() {
    final set = ref.read(openSetProvider);
    final byIdentity = <String, String>{
      for (final entry in set.entries) entry.identity: entry.file.path,
    };
    final ordered = <String>[
      for (final identity in set.recentOrder) ?byIdentity[identity],
      for (final entry in set.entries)
        if (!set.recentOrder.contains(entry.identity)) entry.file.path,
    ];
    final open = <String>{for (final path in ordered) path.toLowerCase()};

    return <SwitcherEntry>[
      for (final path in ordered) _entry(path, open: true),
      for (final path in ref.read(recentFilesProvider))
        if (!open.contains(path.toLowerCase())) _entry(path, open: false),
    ];
  }

  static SwitcherEntry _entry(String path, {required bool open}) {
    final name = ExtensionRegistry.basenameOf(path);
    final cut = path.length - name.length - 1;
    return (
      path: path,
      name: name,
      folder: cut <= 0 ? '' : path.substring(0, cut),
      open: open,
    );
  }

  List<SwitcherEntry> _ranked() => fuzzyRank<SwitcherEntry>(
    query: _query.text.trim(),
    items: _candidates(),
    // The whole path, so a query can reach a folder — doc 08 asks for "names
    // + relative paths". The scorer's last-segment bonus is what keeps the
    // filename winning anyway.
    label: (entry) => entry.path,
  );

  void _move(int delta, int count) {
    if (count == 0) {
      return;
    }
    setState(() => _selected = (_selected + delta + count) % count);
    // A selection that has scrolled out of view is a selection you cannot see
    // yourself making.
    if (_list.hasClients) {
      _list.animateTo(
        (_selected * rowExtent).clamp(0, _list.position.maxScrollExtent),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    }
  }

  void _choose(SwitcherEntry entry) {
    Navigator.of(context).pop();
    ref.read(openSetProvider.notifier).openPaths(<String>[entry.path]);
  }

  KeyEventResult _onKey(List<SwitcherEntry> rows, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _move(1, rows.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1, rows.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_selected < rows.length) {
          _choose(rows[_selected]);
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = ReaderTokens.of(context);
    final rows = _rows = _ranked();

    return Align(
      alignment: const Alignment(0, -0.6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 420),
        child: Material(
          color: tokens.bgAlt,
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _query,
                  focusNode: _field,
                  autofocus: true,
                  onChanged: (_) => setState(() => _selected = 0),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.quickSwitcherHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Text(
                    l10n.quickSwitcherEmpty,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    controller: _list,
                    shrinkWrap: true,
                    itemExtent: rowExtent,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => _Row(
                      entry: rows[index],
                      selected: index == _selected,
                      onTap: () => _choose(rows[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final SwitcherEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? tokens.selection : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    entry.folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.fgMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!entry.open)
              Text(
                // A recent file that is not open will be *opened* by choosing
                // it, and that is worth saying before the click rather than
                // after: the open set is the thing this app is about.
                l10n.quickSwitcherRecentBadge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.fgMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
