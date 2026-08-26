import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/files/natural_sort.dart';
import 'package:marklens/core/models/open_set.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The file list beside the reader.
///
/// Two presentations, as doc 06 asks: a **flat list** when documents were
/// opened one at a time, and a **tree** grouped by open root when a folder was
/// opened. Both are one `ListView.builder` over a flattened row list, because
/// a thousand entries have to scroll cold without jank and a widget per entry
/// built up front does not.
///
/// It reads the open set through `app/providers.dart` and knows nothing about
/// the tab strip, which shows the same state a different way
/// (`docs/02_ARCHITECTURE.md`).
class SidebarTree extends ConsumerWidget {
  /// Creates the sidebar.
  const SidebarTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = ref.watch(openSetProvider);
    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);

    if (set.isEmpty) {
      return Container(
        key: const Key('sidebar'),
        color: tokens.bgAlt,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.sidebarEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
        ),
      );
    }

    final rows = buildRows(set);

    return ColoredBox(
      key: const Key('sidebar'),
      color: tokens.bgAlt,
      child: ListView.builder(
        primary: false,
        itemCount: rows.length,
        itemExtent: 26,
        itemBuilder: (context, index) {
          final row = rows[index];
          return row.entry == null
              ? _GroupRow(label: row.label)
              : _FileRow(
                  row: row,
                  active: row.entry!.identity == set.activeIdentity,
                  onActivate: () => ref
                      .read(openSetProvider.notifier)
                      .activate(row.entry!.identity),
                  onTogglePin: () => ref
                      .read(openSetProvider.notifier)
                      .togglePin(row.entry!.identity),
                  onClose: () => ref
                      .read(openSetProvider.notifier)
                      .close(row.entry!.identity),
                );
        },
      ),
    );
  }

  /// Flattens [set] into the rows the list shows.
  ///
  /// Pure, and public, so the grouping and ordering can be asserted without
  /// pumping a widget — the part worth testing here is which rows appear in
  /// which order, not how they are painted.
  static List<SidebarRow> buildRows(OpenSet set) {
    final rows = <SidebarRow>[];
    final claimed = <String>{};

    // Tree mode, one group per open root, roots in the order they were opened.
    for (final root in set.roots) {
      final prefix = _asPrefix(root);
      final under = <OpenEntry>[
        for (final entry in set.entries)
          if (!claimed.contains(entry.identity) &&
              _startsWithPath(entry.file.path, prefix))
            entry,
      ];
      if (under.isEmpty) {
        continue;
      }
      for (final entry in under) {
        claimed.add(entry.identity);
      }
      // Sorted by the path below the root, so files group by folder and read
      // `2.md` before `10.md` within one (`docs/07_FILES_AND_WATCH.md`).
      under.sort(
        (a, b) => compareNatural(
          a.file.path.substring(prefix.length),
          b.file.path.substring(prefix.length),
        ),
      );
      rows
        ..add(SidebarRow.group(ExtensionRegistry.basenameOf(root)))
        ..addAll(<SidebarRow>[
          for (final entry in under)
            SidebarRow.file(
              entry: entry,
              label: entry.file.name,
              detail: _relativeFolder(entry.file.path, prefix),
            ),
        ]);
    }

    // Flat list for everything opened on its own.
    final loose = <OpenEntry>[
      for (final entry in set.entries)
        if (!claimed.contains(entry.identity)) entry,
    ];
    if (loose.isNotEmpty) {
      if (rows.isNotEmpty) {
        rows.add(const SidebarRow.group(''));
      }
      rows.addAll(<SidebarRow>[
        for (final entry in loose)
          SidebarRow.file(
            entry: entry,
            label: entry.file.name,
            // The parent folder, so two README.md from different projects are
            // distinguishable at a glance.
            detail: ExtensionRegistry.basenameOf(_parentOf(entry.file.path)),
          ),
      ]);
    }

    return rows;
  }

  static String _asPrefix(String root) {
    final separator = root.contains(r'\') ? r'\' : '/';
    return root.endsWith(separator) ? root : '$root$separator';
  }

  /// Case-insensitive, because Windows paths are.
  static bool _startsWithPath(String path, String prefix) =>
      path.toLowerCase().startsWith(prefix.toLowerCase());

  static String _parentOf(String path) {
    final cut = path.lastIndexOf(RegExp(r'[/\\]'));
    return cut <= 0 ? '' : path.substring(0, cut);
  }

  static String _relativeFolder(String path, String prefix) {
    final relative = path.substring(prefix.length);
    final cut = relative.lastIndexOf(RegExp(r'[/\\]'));
    return cut <= 0 ? '' : relative.substring(0, cut);
  }
}

/// One line of the sidebar: a group header, or a document.
class SidebarRow {
  /// A group header for [label].
  const SidebarRow.group(this.label) : entry = null, detail = '';

  /// A document row.
  const SidebarRow.file({
    required this.entry,
    required this.label,
    required this.detail,
  });

  /// The document, or `null` when this row is a header.
  final OpenEntry? entry;

  /// The file name, or the root's name for a header.
  final String label;

  /// The subtle relative path shown after the name.
  final String detail;
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    if (label.isEmpty) {
      return Center(
        child: Divider(color: tokens.border, indent: 12, endIndent: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.fgMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.row,
    required this.active,
    required this.onActivate,
    required this.onTogglePin,
    required this.onClose,
  });

  final SidebarRow row;
  final bool active;
  final VoidCallback onActivate;
  final VoidCallback onTogglePin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = row.entry!;

    return InkWell(
      onTap: onActivate,
      child: Container(
        color: active ? tokens.bg : null,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
            if (entry.pinned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin, size: 11, color: tokens.fgMuted),
              ),
            Flexible(
              child: Text(
                row.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: entry.file.missing ? tokens.fgMuted : tokens.fg,
                  fontStyle: entry.file.missing ? FontStyle.italic : null,
                  fontWeight: active ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (row.detail.isNotEmpty)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    row.detail,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.fgMuted,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (entry.file.missing)
              Tooltip(
                message: l10n.sidebarMissingBadge,
                child: Icon(
                  Icons.link_off,
                  size: 13,
                  color: tokens.fgMuted,
                ),
              ),
            if (entry.stale)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.circle, size: 7, color: tokens.accent),
              ),
            _RowMenu(
              pinned: entry.pinned,
              onTogglePin: onTogglePin,
              onClose: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.pinned,
    required this.onTogglePin,
    required this.onClose,
  });

  final bool pinned;
  final VoidCallback onTogglePin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);

    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          onPressed: onTogglePin,
          child: Text(pinned ? l10n.sidebarUnpin : l10n.sidebarPin),
        ),
        MenuItemButton(onPressed: onClose, child: Text(l10n.menuCloseTab)),
      ],
      builder: (context, controller, child) => IconButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        iconSize: 13,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        icon: Icon(Icons.more_horiz, color: tokens.fgMuted),
      ),
    );
  }
}
