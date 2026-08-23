import 'package:flutter/material.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The application shell.
///
/// At M0 this is an empty reader: the layout from `docs/06_UI_UX.md` — menu
/// bar, tab strip, sidebar, outline, status bar — lands at M1.
class MarkLensApp extends StatelessWidget {
  /// Creates the app shell.
  const MarkLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: const _EmptyState(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Text(
          l10n.emptyStateDropHint,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
