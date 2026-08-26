import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/open_set.dart';

/// The tab strip: one tab per open document, pinned ones first.
///
/// Reads and writes the open set through `app/providers.dart` and knows
/// nothing about the sidebar, which is a second view of the same state
/// (`docs/02_ARCHITECTURE.md`).
///
/// No overflow chevron. Doc 06 chose `Ctrl+P` over one deliberately: a menu of
/// hidden tabs is a second, worse file list next to the sidebar.
class TabStrip extends ConsumerWidget {
  /// Creates the strip.
  const TabStrip({super.key});

  /// Height of the strip, so the shell can reserve it.
  static const double height = 34;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = ref.watch(openSetProvider);
    if (set.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = ReaderTokens.of(context);
    // Pinned first, insertion order preserved within each group. A stable sort
    // matters: pinning must not shuffle everything else around.
    final ordered = <_TabModel>[
      for (final entry in set.entries)
        if (entry.pinned)
          _TabModel(entry: entry, active: entry.identity == set.activeIdentity),
      for (final entry in set.entries)
        if (!entry.pinned)
          _TabModel(entry: entry, active: entry.identity == set.activeIdentity),
    ];

    return Container(
      key: const Key('tab-strip'),
      height: height,
      decoration: BoxDecoration(
        color: tokens.bgAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ordered.length,
        itemBuilder: (context, index) => _Tab(
          model: ordered[index],
          onActivate: () => ref
              .read(openSetProvider.notifier)
              .activate(ordered[index].entry.identity),
          onClose: () => ref
              .read(openSetProvider.notifier)
              .close(ordered[index].entry.identity),
          onTogglePin: () => ref
              .read(openSetProvider.notifier)
              .togglePin(ordered[index].entry.identity),
        ),
      ),
    );
  }
}

class _TabModel {
  const _TabModel({required this.entry, required this.active});

  final OpenEntry entry;
  final bool active;
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.model,
    required this.onActivate,
    required this.onClose,
    required this.onTogglePin,
  });

  final _TabModel model;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final entry = model.entry;

    return Listener(
      // Middle-click closes (`docs/06_UI_UX.md`). On a Listener rather than a
      // GestureDetector because Flutter's tap recognizers are primary-button
      // only.
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          onClose();
        }
      },
      child: InkWell(
        onTap: onActivate,
        onSecondaryTap: onTogglePin,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: model.active ? tokens.bg : tokens.bgAlt,
            border: Border(
              right: BorderSide(color: tokens.border),
              bottom: BorderSide(
                color: model.active ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (entry.pinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.push_pin,
                    size: 12,
                    color: tokens.fgMuted,
                  ),
                ),
              Flexible(
                child: Text(
                  entry.file.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: entry.file.missing ? tokens.fgMuted : tokens.fg,
                    fontStyle: entry.file.missing ? FontStyle.italic : null,
                    fontWeight: model.active ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (entry.stale)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  // Changed on disk while this tab was in the background.
                  child: Icon(Icons.circle, size: 8, color: tokens.accent),
                ),
              IconButton(
                onPressed: onClose,
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: tokens.fgMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
