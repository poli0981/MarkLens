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
  String get menuFile => '&File';

  @override
  String get menuView => '&View';

  @override
  String get menuHelp => '&Help';

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

  @override
  String get menuOpenRecent => 'Open Recent';

  @override
  String get menuOpenRecentEmpty => 'No recent documents';

  @override
  String get menuReload => 'Reload';

  @override
  String get menuCopyDocument => 'Copy entire document';

  @override
  String get menuCloseTab => 'Close Tab';

  @override
  String get menuCloseAll => 'Close All';

  @override
  String get menuSettings => 'Settings…';

  @override
  String get menuExit => 'Exit';

  @override
  String get menuToggleSidebar => 'Toggle Sidebar';

  @override
  String get menuToggleOutline => 'Toggle Outline';

  @override
  String get menuZoomIn => 'Zoom In';

  @override
  String get menuZoomOut => 'Zoom Out';

  @override
  String get menuZoomReset => 'Reset Zoom';

  @override
  String get menuTheme => 'Theme';

  @override
  String get menuThemeSystem => 'System';

  @override
  String get menuThemeLight => 'Light';

  @override
  String get menuThemeDark => 'Dark';

  @override
  String get menuFullScreen => 'Full Screen';

  @override
  String get menuCheckUpdates => 'Check for Updates…';

  @override
  String get menuThirdPartyLicenses => 'Third-party Licenses';

  @override
  String get menuExportLog => 'Export Diagnostic Log…';

  @override
  String get menuAbout => 'About MarkLens';

  @override
  String menuNotImplemented(String item) {
    return '$item is not wired up yet';
  }

  @override
  String get readerNoticeInvalidUtf8 =>
      'This file is not valid UTF-8. Some characters were replaced.';

  @override
  String get readerNoticeFrontMatterUnparsed =>
      'The front matter is not simple key/value lines, so it is shown as written.';

  @override
  String get readerNoticeMdxBailOut =>
      'Some MDX could not be interpreted and is shown as source.';

  @override
  String get readerNoticePlainTextFallback =>
      'This document could not be parsed and is shown as plain text.';

  @override
  String get readerNoticeLargeDocument =>
      'This is a large document. Some features may be slower than usual.';

  @override
  String get readerCopied => 'Copied';

  @override
  String get readerExpand => 'Expand';

  @override
  String get readerCollapse => 'Collapse';

  @override
  String get readerFrontMatterTitle => 'Front matter';

  @override
  String get readerNoticeDismiss => 'Dismiss';

  @override
  String readerNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more notices',
      one: '1 more notice',
    );
    return '$_temp0';
  }

  @override
  String readerOpenFailed(String name) {
    return '$name could not be opened.';
  }
}
