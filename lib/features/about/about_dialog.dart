import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Help → About MarkLens (`docs/06_UI_UX.md`).
///
/// Until M3 this was Flutter's bare `showAboutDialog` with an application name
/// and nothing else — no version, no licence, no way to reach the source. It
/// is the one screen whose whole job is to say what this program *is*.
///
/// The version comes from [appVersion] rather than from `package_info_plus`.
/// The constant is already the single source of truth for `--version`, already
/// asserted against `pubspec.yaml` by `test/app/version_test.dart`, and works
/// without a platform channel — so a widget test sees the real number, which
/// is the whole point of showing it.
class AboutMarkLens extends ConsumerWidget {
  /// Creates the dialog.
  const AboutMarkLens({super.key});

  /// Shows it over [context].
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => const AboutMarkLens(),
  );

  /// The project's own page, opened through the launcher seam like any other
  /// external link — the scheme check is not skipped for our own URL.
  static final Uri homepage = Uri.parse('https://github.com/poli0981/MarkLens');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.aboutTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.aboutVersion(appVersion),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aboutTagline,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
          ),
          const SizedBox(height: 12),
          Text(
            // GPL-3.0-only, and saying so is a licence obligation rather than
            // a courtesy.
            l10n.aboutLicense,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.fgMuted),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: appVersion,
            applicationLegalese: l10n.aboutLicense,
          ),
          child: Text(l10n.menuThirdPartyLicenses),
        ),
        TextButton(
          onPressed: () => ref.read(launcherLinkProvider).open(homepage),
          child: Text(l10n.aboutHomepage),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
