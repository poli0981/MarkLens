import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// What the reading surface shows when the active tab's file has gone
/// (`docs/06_UI_UX.md`, "Empty & edge states").
///
/// `ActiveDocument.failedPath` has existed since M1 and only the status bar
/// ever read it, so a missing file showed the first-run drop hint — as though
/// nothing were open at all, which is the opposite of what happened.
///
/// The two buttons are doc 06's. **Remove from session** is the only place a
/// missing entry ever leaves: doc 07 keeps entries and badges them until the
/// user says otherwise, and this is them saying otherwise. **Reveal parent
/// folder** goes to the folder rather than the file, because the file is the
/// thing that is not there.
class MissingFileBody extends ConsumerWidget {
  /// Creates the body.
  const MissingFileBody({
    required this.path,
    required this.identity,
    super.key,
  });

  /// The path that could not be read.
  final String path;

  /// Its open-set identity, for removing it.
  final String identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);

    return ColoredBox(
      color: tokens.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.help_outline,
                size: 32,
                color: tokens.fgMuted,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.missingFileTitle(ExtensionRegistry.basenameOf(path)),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.missingFileBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.fgMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                path,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.fgMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              // `Wrap`, not `Row`: doc 09 wants no fixed-width boxes around
              // translated text, and these two labels are long in every
              // language.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(openSetProvider.notifier).remove(identity),
                    child: Text(l10n.missingFileRemove),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(launcherLinkProvider)
                        .reveal(ExtensionRegistry.parentOf(path)),
                    child: Text(l10n.missingFileReveal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
