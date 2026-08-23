// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'MarkLens';

  @override
  String get menuFile => 'ファイル';

  @override
  String get menuView => '表示';

  @override
  String get menuHelp => 'ヘルプ';

  @override
  String get menuOpenFiles => 'ファイルを開く…';

  @override
  String get menuOpenFolder => 'フォルダーを開く…';

  @override
  String get readerCopyCodeTooltip => 'コードをコピー';

  @override
  String get sidebarMissingBadge => '見つかりません';

  @override
  String get readerRawHtmlTitle => '生の HTML（描画しません）';

  @override
  String readerMdxImportsHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の import を非表示',
    );
    return 'MDX · $_temp0';
  }

  @override
  String get emptyStateDropHint => 'Markdown ファイルをここにドロップするか、開いて始めてください。';
}
