// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MarkLens';

  @override
  String get menuFile => 'File';

  @override
  String get menuView => 'View';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuOpenFiles => 'Open File(s)…';

  @override
  String get menuOpenFolder => 'Open Folder…';

  @override
  String get readerCopyCodeTooltip => 'Copy code';

  @override
  String get sidebarMissingBadge => 'missing';

  @override
  String get readerRawHtmlTitle => 'Raw HTML (not rendered)';

  @override
  String readerMdxImportsHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imports hidden',
      one: '1 import hidden',
    );
    return 'MDX · $_temp0';
  }

  @override
  String get emptyStateDropHint =>
      'Drop a Markdown file here, or open one to begin.';
}
