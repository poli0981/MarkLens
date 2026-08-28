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
  String readerMdxComponentTitle(String name) {
    return '$name（MDX コンポーネント、描画しません）';
  }

  @override
  String readerMdxComponentAttributes(String names) {
    return '属性: $names';
  }

  @override
  String readerLinkUnsupported(String kind) {
    return 'MarkLens は $kind リンクを開きません。';
  }

  @override
  String readerLinkMissingTarget(String name) {
    return '$name はもうありません。';
  }

  @override
  String readerLinkMissingAnchor(String anchor) {
    return '#$anchor に一致する見出しがありません。';
  }

  @override
  String readerLinkLaunchFailed(String host) {
    return '$host をブラウザーに渡せませんでした。';
  }

  @override
  String get readerImageMissing => '画像が見つかりません';

  @override
  String get readerImageUnsupported => '対応していない画像形式です';

  @override
  String get readerImageRemoteBlocked =>
      'リモート画像をブロックしました。設定でリモート画像を有効にすると読み込みます。';

  @override
  String readerImageTooLarge(String name) {
    return '$name は大きいため自動では表示しません。';
  }

  @override
  String get readerImageLoadAnyway => 'それでも読み込む';

  @override
  String get readerImageFailed => 'この画像は表示できませんでした。';

  @override
  String get searchAcrossHint => '開いているファイルを検索';

  @override
  String get searchAcrossRunning => '検索中…';

  @override
  String get searchAcrossNoMatches => '開いているファイルに一致はありません';

  @override
  String searchAcrossSummary(int matches, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files 件のファイル',
    );
    String _temp1 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches 件',
    );
    return '$_temp0で$_temp1';
  }

  @override
  String searchAcrossTruncated(int count) {
    return '$count+';
  }

  @override
  String get searchAcrossClose => '検索を閉じる';

  @override
  String get quickSwitcherHint => 'ファイルへ移動';

  @override
  String get quickSwitcherEmpty => '一致するものがありません';

  @override
  String get quickSwitcherRecentBadge => '最近';

  @override
  String get menuOpenRecentClear => '最近使った項目を消去';

  @override
  String get emptyStateRecent => '最近使った項目';

  @override
  String get aboutTitle => 'MarkLens について';

  @override
  String aboutVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get aboutTagline => '軽快で読み取り専用の Markdown ビューアー。';

  @override
  String get aboutLicense => 'GPL-3.0-only。無保証のフリーソフトウェアです。';

  @override
  String get aboutHomepage => 'プロジェクトページ';

  @override
  String get commonClose => '閉じる';

  @override
  String updateAvailable(String version) {
    return 'MarkLens $version が利用できます';
  }

  @override
  String get updateOpenRelease => '変更点を見る';

  @override
  String get updateUpToDate => 'MarkLens は最新です。';

  @override
  String get updateChecksOff => '更新の確認は設定でオフになっています。';

  @override
  String get logExportSuggestedName => 'marklens-log';

  @override
  String logExportWritten(String path) {
    return '診断ログを $path に書き出しました。';
  }

  @override
  String get logExportFailed => 'そこには診断ログを書き出せませんでした。';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionGeneral => '全般';

  @override
  String get settingsSectionReading => '表示';

  @override
  String get settingsSectionFiles => 'ファイル';

  @override
  String get settingsSectionNetwork => 'ネットワーク';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsFollowSystem => 'システムに従う';

  @override
  String get settingsRestoreSession => '起動時に前回のセッションを復元する';

  @override
  String get settingsRecentLimit => '保持する最近使った文書の数';

  @override
  String get settingsFontScale => '文字サイズ';

  @override
  String get settingsContentWidth => '本文の幅';

  @override
  String get settingsContentWidthFull => '全幅';

  @override
  String get settingsFrontMatter => 'フロントマター';

  @override
  String get settingsFrontMatterCollapsed => '折りたたむ';

  @override
  String get settingsFrontMatterExpanded => '展開する';

  @override
  String get settingsFrontMatterHidden => '表示しない';

  @override
  String get settingsExtensions => 'MarkLens が開く拡張子';

  @override
  String get settingsExtensionsHint => '拡張子を追加';

  @override
  String get settingsAdd => '追加';

  @override
  String get settingsFileCap => '1 つのフォルダーで開く上限';

  @override
  String get settingsWatch => 'ディスク上で変更されたら再読み込みする';

  @override
  String get settingsRemoteImages => 'インターネットから画像を読み込む';

  @override
  String get settingsRemoteImagesDetail =>
      '既定はオフ。ホストを指定した文書は、それを使ってあなたが開いたことを知ることができます。';

  @override
  String get settingsUpdateCheck => '新しいバージョンを確認する';

  @override
  String get settingsUpdateCheckDetail =>
      'GitHub に 1 日 1 回まで。あなたに関する情報は送信しません。';

  @override
  String get dropOverlay => 'ドロップして開く';

  @override
  String openTooLarge(String name) {
    return '$name は大きすぎて開けません。';
  }

  @override
  String get openTooLargeBody =>
      'MarkLens が開けるのは 50 MB までです。このファイルはそれより大きく、快適に表示できる文書ではありません。';

  @override
  String missingFileTitle(String name) {
    return '$name はもうありません。';
  }

  @override
  String get missingFileBody =>
      '移動、名前の変更、または削除された可能性があります。戻ってくる場合に備えて、閉じるまでタブは残ります。';

  @override
  String get missingFileRemove => 'セッションから削除';

  @override
  String get missingFileReveal => '親フォルダーを表示';

  @override
  String get sidebarReveal => 'ファイルマネージャーで表示';

  @override
  String get revealFailed => 'そのフォルダーを開けませんでした。';

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
  String get readerNoticeInvalidUtf8 =>
      'このファイルは有効な UTF-8 ではありません。一部の文字を置き換えました。';

  @override
  String get readerNoticeFrontMatterUnparsed =>
      'front matter が単純なキー値形式ではないため、記述どおりに表示しています。';

  @override
  String get readerNoticeMdxBailOut => '解釈できない MDX があるため、ソースとして表示しています。';

  @override
  String get readerNoticePlainTextFallback =>
      'この文書を解析できなかったため、プレーンテキストとして表示しています。';

  @override
  String get readerNoticeLargeDocument => '大きな文書です。一部の機能が通常より遅くなる場合があります。';

  @override
  String get readerCopied => 'コピーしました';

  @override
  String get readerExpand => '展開';

  @override
  String get readerCollapse => '折りたたむ';

  @override
  String get readerFrontMatterTitle => 'front matter';

  @override
  String get readerNoticeDismiss => '閉じる';

  @override
  String readerNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他に $count 件の通知',
    );
    return '$_temp0';
  }

  @override
  String readerOpenFailed(String name) {
    return '$name を開けませんでした。';
  }

  @override
  String get sidebarEmpty => '開いている文書はありません。';

  @override
  String get sidebarPin => 'ピン留め';

  @override
  String get sidebarUnpin => 'ピン留めを解除';

  @override
  String openFolderCapTitle(int count) {
    return 'このフォルダーには $count 件を超える文書があります';
  }

  @override
  String openFolderCapBody(int count) {
    return 'MarkLens は先頭の $count 件を開けます。すべて開くとサイドバーとセッションが見合わないほど遅くなります。';
  }

  @override
  String openFolderCapAccept(int count) {
    return '先頭の $count 件を開く';
  }

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get sessionNotRestored => '前回のセッションを読み取れませんでした。新しいセッションの横に保存してあります。';

  @override
  String statusBarPosition(int percent) {
    return '$percent%';
  }

  @override
  String statusBarWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 語',
    );
    return '$_temp0';
  }

  @override
  String statusBarNotices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の通知',
    );
    return '$_temp0';
  }

  @override
  String get statusBarNoDocument => '文書が開かれていません';

  @override
  String get outlinePanelTitle => 'アウトライン';

  @override
  String get settingsNotRestored => '設定を読み取れませんでした。新しい初期設定の横に保存してあります。';

  @override
  String get outlineEmpty => 'この文書には見出しがありません。';

  @override
  String get findPlaceholder => '文書内を検索';

  @override
  String findMatchCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String get findNoResults => '一致なし';

  @override
  String get findCaseSensitive => '大文字と小文字を区別';

  @override
  String get findNext => '次の一致';

  @override
  String get findPrevious => '前の一致';

  @override
  String get findClose => '検索を閉じる';
}
