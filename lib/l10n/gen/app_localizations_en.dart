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
  String readerMdxComponentTitle(String name) {
    return '$name (MDX component, not rendered)';
  }

  @override
  String readerMdxComponentAttributes(String names) {
    return 'Attributes: $names';
  }

  @override
  String readerLinkUnsupported(String kind) {
    return 'MarkLens doesn’t open $kind links.';
  }

  @override
  String readerLinkMissingTarget(String name) {
    return '$name isn’t there any more.';
  }

  @override
  String readerLinkMissingAnchor(String anchor) {
    return 'No heading matches #$anchor.';
  }

  @override
  String readerLinkLaunchFailed(String host) {
    return 'Couldn’t hand $host to the browser.';
  }

  @override
  String get readerImageMissing => 'Image not found';

  @override
  String get readerImageUnsupported => 'Not a supported image';

  @override
  String get readerImageRemoteBlocked =>
      'Remote image blocked. Turn on remote images in Settings to load it.';

  @override
  String readerImageTooLarge(String name) {
    return '$name is large, so it is not shown automatically.';
  }

  @override
  String get readerImageLoadAnyway => 'Load anyway';

  @override
  String get readerImageFailed => 'This image could not be displayed.';

  @override
  String get searchAcrossHint => 'Search open files';

  @override
  String get searchAcrossRunning => 'Searching…';

  @override
  String get searchAcrossNoMatches => 'No matches in the open files';

  @override
  String searchAcrossSummary(int matches, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches matches',
      one: '1 match',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String searchAcrossTruncated(int count) {
    return '$count+';
  }

  @override
  String get searchAcrossClose => 'Close search';

  @override
  String get quickSwitcherHint => 'Go to file';

  @override
  String get quickSwitcherEmpty => 'Nothing matches';

  @override
  String get quickSwitcherRecentBadge => 'recent';

  @override
  String get menuOpenRecentClear => 'Clear recent list';

  @override
  String get emptyStateRecent => 'Recent';

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

  @override
  String get sidebarEmpty => 'No documents open.';

  @override
  String get sidebarPin => 'Pin';

  @override
  String get sidebarUnpin => 'Unpin';

  @override
  String openFolderCapTitle(int count) {
    return 'That folder holds more than $count documents';
  }

  @override
  String openFolderCapBody(int count) {
    return 'MarkLens can open the first $count of them. Opening the rest would make the sidebar and the session slower than they are worth.';
  }

  @override
  String openFolderCapAccept(int count) {
    return 'Open first $count';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get sessionNotRestored =>
      'The previous session could not be read. It has been kept alongside a fresh one.';

  @override
  String statusBarPosition(int percent) {
    return '$percent%';
  }

  @override
  String statusBarWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String statusBarNotices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notices',
      one: '1 notice',
    );
    return '$_temp0';
  }

  @override
  String get statusBarNoDocument => 'No document open';

  @override
  String get outlinePanelTitle => 'Outline';

  @override
  String get settingsNotRestored =>
      'Your settings could not be read. They have been kept alongside fresh defaults.';

  @override
  String get outlineEmpty => 'This document has no headings.';

  @override
  String get findPlaceholder => 'Find in document';

  @override
  String findMatchCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String get findNoResults => 'No matches';

  @override
  String get findCaseSensitive => 'Match case';

  @override
  String get findNext => 'Next match';

  @override
  String get findPrevious => 'Previous match';

  @override
  String get findClose => 'Close find';
}
