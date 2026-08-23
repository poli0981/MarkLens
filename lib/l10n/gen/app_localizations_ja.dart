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
  String get menuFile => 'ファイル(&F)';

  @override
  String get menuView => '表示(&V)';

  @override
  String get menuHelp => 'ヘルプ(&H)';

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

  @override
  String get menuOpenRecent => '最近使った項目';

  @override
  String get menuOpenRecentEmpty => '最近使った文書はありません';

  @override
  String get menuReload => '再読み込み';

  @override
  String get menuCopyDocument => '文書全体をコピー';

  @override
  String get menuCloseTab => 'タブを閉じる';

  @override
  String get menuCloseAll => 'すべて閉じる';

  @override
  String get menuSettings => '設定…';

  @override
  String get menuExit => '終了';

  @override
  String get menuToggleSidebar => 'サイドバーの表示切替';

  @override
  String get menuToggleOutline => 'アウトラインの表示切替';

  @override
  String get menuZoomIn => '拡大';

  @override
  String get menuZoomOut => '縮小';

  @override
  String get menuZoomReset => '拡大率をリセット';

  @override
  String get menuTheme => 'テーマ';

  @override
  String get menuThemeSystem => 'システムに従う';

  @override
  String get menuThemeLight => 'ライト';

  @override
  String get menuThemeDark => 'ダーク';

  @override
  String get menuFullScreen => '全画面表示';

  @override
  String get menuCheckUpdates => '更新を確認…';

  @override
  String get menuThirdPartyLicenses => 'サードパーティライセンス';

  @override
  String get menuExportLog => '診断ログを書き出す…';

  @override
  String get menuAbout => 'MarkLens について';

  @override
  String menuNotImplemented(String item) {
    return '$item はまだ接続されていません';
  }
}
