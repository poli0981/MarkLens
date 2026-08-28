import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('vi'),
  ];

  /// Application name. Window title and About screen.
  ///
  /// In en, this message translates to:
  /// **'MarkLens'**
  String get appTitle;

  /// Menu bar: File menu label. The '&' marks the Alt accelerator letter and is stripped before display (MenuAcceleratorLabel).
  ///
  /// In en, this message translates to:
  /// **'&File'**
  String get menuFile;

  /// Menu bar: View menu label. '&' marks the Alt accelerator letter.
  ///
  /// In en, this message translates to:
  /// **'&View'**
  String get menuView;

  /// Menu bar: Help menu label. '&' marks the Alt accelerator letter.
  ///
  /// In en, this message translates to:
  /// **'&Help'**
  String get menuHelp;

  /// File menu: open one or more documents.
  ///
  /// In en, this message translates to:
  /// **'Open File(s)…'**
  String get menuOpenFiles;

  /// File menu: open a folder of documents.
  ///
  /// In en, this message translates to:
  /// **'Open Folder…'**
  String get menuOpenFolder;

  /// Tooltip on the copy button of a fenced code block.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get readerCopyCodeTooltip;

  /// Sidebar badge on a file that no longer exists on disk.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get sidebarMissingBadge;

  /// Title of the collapsed box holding block HTML. MarkLens never renders HTML (docs/04).
  ///
  /// In en, this message translates to:
  /// **'Raw HTML (not rendered)'**
  String get readerRawHtmlTitle;

  /// Chip in the document header when the MDX sanitizer removed ESM import/export lines.
  ///
  /// In en, this message translates to:
  /// **'MDX · {count, plural, =1{1 import hidden} other{{count} imports hidden}}'**
  String readerMdxImportsHidden(int count);

  /// Title of the collapsed placeholder card standing in for an MDX component. Render, not run (docs/04).
  ///
  /// In en, this message translates to:
  /// **'{name} (MDX component, not rendered)'**
  String readerMdxComponentTitle(String name);

  /// Tooltip over the attribute-name summary on an MDX placeholder card.
  ///
  /// In en, this message translates to:
  /// **'Attributes: {names}'**
  String readerMdxComponentAttributes(String names);

  /// Notice after clicking a link that is neither http(s) nor a document MarkLens opens. Never followed (docs/10).
  ///
  /// In en, this message translates to:
  /// **'MarkLens doesn’t open {kind} links.'**
  String readerLinkUnsupported(String kind);

  /// Notice after clicking a relative link whose target file does not exist.
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t there any more.'**
  String readerLinkMissingTarget(String name);

  /// Notice after clicking an anchor link with no matching heading slug (docs/04).
  ///
  /// In en, this message translates to:
  /// **'No heading matches #{anchor}.'**
  String readerLinkMissingAnchor(String anchor);

  /// Notice when the platform refused to open an external URL.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t hand {host} to the browser.'**
  String readerLinkLaunchFailed(String host);

  /// Placeholder for a local image whose resolved path does not exist. The path is shown beneath, untranslated.
  ///
  /// In en, this message translates to:
  /// **'Image not found'**
  String get readerImageMissing;

  /// Placeholder for a src outside the extension allowlist, or with a scheme MarkLens does not load (docs/04).
  ///
  /// In en, this message translates to:
  /// **'Not a supported image'**
  String get readerImageUnsupported;

  /// Placeholder for an http(s) image while network.allowRemoteImages is off, which is the default (docs/10).
  ///
  /// In en, this message translates to:
  /// **'Remote image blocked. Turn on remote images in Settings to load it.'**
  String get readerImageRemoteBlocked;

  /// Placeholder for a local image over the size guard, shown with a load-anyway button.
  ///
  /// In en, this message translates to:
  /// **'{name} is large, so it is not shown automatically.'**
  String readerImageTooLarge(String name);

  /// Button on the oversize-image placeholder. Still local, still user-initiated.
  ///
  /// In en, this message translates to:
  /// **'Load anyway'**
  String get readerImageLoadAnyway;

  /// Placeholder shown when a decoder gave up on the bytes (CLAUDE.md rule 9).
  ///
  /// In en, this message translates to:
  /// **'This image could not be displayed.'**
  String get readerImageFailed;

  /// Placeholder in the Ctrl+Shift+F panel's query field (docs/08).
  ///
  /// In en, this message translates to:
  /// **'Search open files'**
  String get searchAcrossHint;

  /// Shown while a cross-file scan is in flight.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchAcrossRunning;

  /// Shown when a cross-file search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches in the open files'**
  String get searchAcrossNoMatches;

  /// Result count above the cross-file result list.
  ///
  /// In en, this message translates to:
  /// **'{matches, plural, =1{1 match} other{{matches} matches}} in {files, plural, =1{1 file} other{{files} files}}'**
  String searchAcrossSummary(int matches, int files);

  /// Hit count for a file where the per-file cap cut the list short. Never a silent truncation (docs/08).
  ///
  /// In en, this message translates to:
  /// **'{count}+'**
  String searchAcrossTruncated(int count);

  /// Tooltip on the button that puts the file list back in the sidebar column.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchAcrossClose;

  /// Placeholder in the Ctrl+P quick switcher (docs/08).
  ///
  /// In en, this message translates to:
  /// **'Go to file'**
  String get quickSwitcherHint;

  /// Shown in the quick switcher when the query matches no open or recent file.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get quickSwitcherEmpty;

  /// Badge on a quick-switcher row for a file that is not open, and will be opened by choosing it.
  ///
  /// In en, this message translates to:
  /// **'recent'**
  String get quickSwitcherRecentBadge;

  /// Last item of File > Open Recent.
  ///
  /// In en, this message translates to:
  /// **'Clear recent list'**
  String get menuOpenRecentClear;

  /// Heading above the recent-file list on the first-run empty state (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get emptyStateRecent;

  /// Title of the About dialog.
  ///
  /// In en, this message translates to:
  /// **'About MarkLens'**
  String get aboutTitle;

  /// Version line in the About dialog.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// One-line description of the app, from pubspec.yaml.
  ///
  /// In en, this message translates to:
  /// **'A fast, lightweight, read-only Markdown viewer.'**
  String get aboutTagline;

  /// Licence line in the About dialog. Stating it is an obligation, not a courtesy.
  ///
  /// In en, this message translates to:
  /// **'GPL-3.0-only. Free software, with no warranty.'**
  String get aboutLicense;

  /// Button in the About dialog that opens the repository in the browser.
  ///
  /// In en, this message translates to:
  /// **'Project page'**
  String get aboutHomepage;

  /// Generic close button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Passive banner shown when the release check found a newer version (docs/11).
  ///
  /// In en, this message translates to:
  /// **'MarkLens {version} is available'**
  String updateAvailable(String version);

  /// Button on the update banner. It opens the release page; MarkLens never downloads anything itself.
  ///
  /// In en, this message translates to:
  /// **'See what changed'**
  String get updateOpenRelease;

  /// Answer to Help > Check for Updates when there is nothing newer. Only ever shown for a check the user asked for.
  ///
  /// In en, this message translates to:
  /// **'MarkLens is up to date.'**
  String get updateUpToDate;

  /// Answer to Help > Check for Updates while network.updateCheck is off. The menu item does not override the setting.
  ///
  /// In en, this message translates to:
  /// **'Update checks are turned off in Settings.'**
  String get updateChecksOff;

  /// Default filename offered by the diagnostic-log save dialog, without its extension.
  ///
  /// In en, this message translates to:
  /// **'marklens-log'**
  String get logExportSuggestedName;

  /// Confirmation after exporting the diagnostic log.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic log written to {path}.'**
  String logExportWritten(String path);

  /// Shown when the chosen destination could not be written to.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t write the diagnostic log there.'**
  String get logExportFailed;

  /// Title of the settings screen (Ctrl+,).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsSectionReading;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get settingsSectionFiles;

  /// Settings section heading. MarkLens makes exactly two network calls, both here.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsSectionNetwork;

  /// UI language setting (docs/09).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Choice meaning follow the operating system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsFollowSystem;

  /// settings.restoreSession (docs/05).
  ///
  /// In en, this message translates to:
  /// **'Reopen last session at startup'**
  String get settingsRestoreSession;

  /// settings.recentLimit, 0-200 (docs/05).
  ///
  /// In en, this message translates to:
  /// **'Recent documents kept'**
  String get settingsRecentLimit;

  /// reading.fontScale, 50-300%. Scales the document, not the window chrome (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsFontScale;

  /// reading.contentMaxWidth in logical pixels, or full width.
  ///
  /// In en, this message translates to:
  /// **'Reading column width'**
  String get settingsContentWidth;

  /// Shown at the zero end of the column-width slider.
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get settingsContentWidthFull;

  /// reading.frontMatter display mode (docs/04).
  ///
  /// In en, this message translates to:
  /// **'Front matter'**
  String get settingsFrontMatter;

  /// Front-matter panel opens collapsed.
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get settingsFrontMatterCollapsed;

  /// Front-matter panel opens expanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get settingsFrontMatterExpanded;

  /// Front-matter panel is not shown.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get settingsFrontMatterHidden;

  /// files.extensions. Gates folder scans, the dialog filter, drag-drop and CLI args alike (docs/07).
  ///
  /// In en, this message translates to:
  /// **'File extensions MarkLens opens'**
  String get settingsExtensions;

  /// Placeholder in the add-extension field.
  ///
  /// In en, this message translates to:
  /// **'Add an extension'**
  String get settingsExtensionsHint;

  /// Button that adds the typed extension.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get settingsAdd;

  /// files.fileCap, 100-2000 (docs/07).
  ///
  /// In en, this message translates to:
  /// **'Most files one folder may open'**
  String get settingsFileCap;

  /// files.watchEnabled (docs/07).
  ///
  /// In en, this message translates to:
  /// **'Reload documents when they change on disk'**
  String get settingsWatch;

  /// network.allowRemoteImages, off by default (docs/10).
  ///
  /// In en, this message translates to:
  /// **'Load images from the internet'**
  String get settingsRemoteImages;

  /// Why remote images default to off - the tracking-beacon reason from doc 10.
  ///
  /// In en, this message translates to:
  /// **'Off by default: a document naming a host can use it to see that you opened it.'**
  String get settingsRemoteImagesDetail;

  /// network.updateCheck (docs/11).
  ///
  /// In en, this message translates to:
  /// **'Check for new versions'**
  String get settingsUpdateCheck;

  /// What the update check does, stated where the switch is.
  ///
  /// In en, this message translates to:
  /// **'At most once a day, to GitHub. Nothing about you is sent.'**
  String get settingsUpdateCheckDetail;

  /// Overlay shown while files are dragged over the window (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Drop to open'**
  String get dropOverlay;

  /// Dialog when a document is over the 50 MB limit. MarkLens is a viewer, not a log reader (docs/00, docs/04).
  ///
  /// In en, this message translates to:
  /// **'{name} is too large to open.'**
  String openTooLarge(String name);

  /// Explanation under openTooLarge.
  ///
  /// In en, this message translates to:
  /// **'MarkLens opens documents up to 50 MB. This one is bigger, so it is not a document MarkLens can show you comfortably.'**
  String get openTooLargeBody;

  /// Body shown when the active tab's file has gone (docs/06, edge states).
  ///
  /// In en, this message translates to:
  /// **'{name} isn’t there any more.'**
  String missingFileTitle(String name);

  /// Explanation under missingFileTitle. Doc 07: entries leave the session only when the user closes them.
  ///
  /// In en, this message translates to:
  /// **'It may have been moved, renamed or deleted. The tab stays until you close it, in case it comes back.'**
  String get missingFileBody;

  /// Button on the missing-file body.
  ///
  /// In en, this message translates to:
  /// **'Remove from session'**
  String get missingFileRemove;

  /// Button on the missing-file body, and the sidebar context menu.
  ///
  /// In en, this message translates to:
  /// **'Reveal parent folder'**
  String get missingFileReveal;

  /// Sidebar context menu (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Reveal in file manager'**
  String get sidebarReveal;

  /// Sidebar row menu: keep this document at the left of the tab strip.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get sidebarPin;

  /// Sidebar row menu: stop pinning this document.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get sidebarUnpin;

  /// Sidebar context menu: close this document.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get sidebarClose;

  /// Shown when the file manager would not open.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open that folder.'**
  String get revealFailed;

  /// First-run empty state, shown when nothing is open.
  ///
  /// In en, this message translates to:
  /// **'Drop a Markdown file here, or open one to begin.'**
  String get emptyStateDropHint;

  /// File menu: submenu of recently opened documents.
  ///
  /// In en, this message translates to:
  /// **'Open Recent'**
  String get menuOpenRecent;

  /// Placeholder inside the Open Recent submenu when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No recent documents'**
  String get menuOpenRecentEmpty;

  /// File menu: re-read the active document from disk.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get menuReload;

  /// File menu: copy the whole Markdown source to the clipboard (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Copy entire document'**
  String get menuCopyDocument;

  /// File menu: close the active tab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get menuCloseTab;

  /// File menu: close every open tab.
  ///
  /// In en, this message translates to:
  /// **'Close All'**
  String get menuCloseAll;

  /// File menu: open the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get menuSettings;

  /// File menu: quit MarkLens.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get menuExit;

  /// View menu: show or hide the file sidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sidebar'**
  String get menuToggleSidebar;

  /// View menu: show or hide the outline panel.
  ///
  /// In en, this message translates to:
  /// **'Toggle Outline'**
  String get menuToggleOutline;

  /// View menu: increase the reading zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get menuZoomIn;

  /// View menu: decrease the reading zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get menuZoomOut;

  /// View menu: return the reading zoom to 100%.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get menuZoomReset;

  /// View menu: submenu choosing the colour theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get menuTheme;

  /// Theme submenu: follow the operating system setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get menuThemeSystem;

  /// Theme submenu: always light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get menuThemeLight;

  /// Theme submenu: always dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get menuThemeDark;

  /// View menu: enter or leave full screen.
  ///
  /// In en, this message translates to:
  /// **'Full Screen'**
  String get menuFullScreen;

  /// Help menu: ask GitHub whether a newer release exists.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates…'**
  String get menuCheckUpdates;

  /// Help menu: show the bundled dependency licences.
  ///
  /// In en, this message translates to:
  /// **'Third-party Licenses'**
  String get menuThirdPartyLicenses;

  /// Help menu: write the in-memory log to a file the user picks.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostic Log…'**
  String get menuExportLog;

  /// Help menu: version and project information.
  ///
  /// In en, this message translates to:
  /// **'About MarkLens'**
  String get menuAbout;

  /// Notice bar for DocNoticeKind.invalidUtf8 (docs/04 stage 1).
  ///
  /// In en, this message translates to:
  /// **'This file is not valid UTF-8. Some characters were replaced.'**
  String get readerNoticeInvalidUtf8;

  /// Notice bar for DocNoticeKind.frontMatterUnparsed (docs/04 stage 2).
  ///
  /// In en, this message translates to:
  /// **'The front matter is not simple key/value lines, so it is shown as written.'**
  String get readerNoticeFrontMatterUnparsed;

  /// Notice bar for DocNoticeKind.mdxBailOut. Bailing out is correct behaviour, not an error (docs/04).
  ///
  /// In en, this message translates to:
  /// **'Some MDX could not be interpreted and is shown as source.'**
  String get readerNoticeMdxBailOut;

  /// Notice bar for DocNoticeKind.plainTextFallback (CLAUDE.md rule 9).
  ///
  /// In en, this message translates to:
  /// **'This document could not be parsed and is shown as plain text.'**
  String get readerNoticePlainTextFallback;

  /// Notice bar for DocNoticeKind.largeDocument, over the 10 MB threshold (docs/04).
  ///
  /// In en, this message translates to:
  /// **'This is a large document. Some features may be slower than usual.'**
  String get readerNoticeLargeDocument;

  /// Tooltip on the code copy button just after it was used.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get readerCopied;

  /// Tooltip on the control that opens the collapsed raw-HTML box.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get readerExpand;

  /// Tooltip on the control that closes the raw-HTML box.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get readerCollapse;

  /// Header of the collapsible panel holding a document's leading --- block (docs/04).
  ///
  /// In en, this message translates to:
  /// **'Front matter'**
  String get readerFrontMatterTitle;

  /// Tooltip on the notice bar's close button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get readerNoticeDismiss;

  /// Shown beside a notice when a document raised more than one.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more notice} other{{count} more notices}}'**
  String readerNoticeMore(int count);

  /// Snackbar when a chosen file cannot be read at all.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be opened.'**
  String readerOpenFailed(String name);

  /// Sidebar placeholder before anything has been opened.
  ///
  /// In en, this message translates to:
  /// **'No documents open.'**
  String get sidebarEmpty;

  /// Dialog title when a folder scan hits the soft cap (docs/07).
  ///
  /// In en, this message translates to:
  /// **'That folder holds more than {count} documents'**
  String openFolderCapTitle(int count);

  /// Dialog body for the folder cap.
  ///
  /// In en, this message translates to:
  /// **'MarkLens can open the first {count} of them. Opening the rest would make the sidebar and the session slower than they are worth.'**
  String openFolderCapBody(int count);

  /// Confirm button for the folder cap dialog.
  ///
  /// In en, this message translates to:
  /// **'Open first {count}'**
  String openFolderCapAccept(int count);

  /// Generic cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Snackbar when session.json was corrupt or written by a newer version (docs/05).
  ///
  /// In en, this message translates to:
  /// **'The previous session could not be read. It has been kept alongside a fresh one.'**
  String get sessionNotRestored;

  /// Status bar: how far through the document the reader has scrolled (docs/06).
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String statusBarPosition(int percent);

  /// Status bar: words in the document, fenced code excluded (docs/06). Each CJK character counts as one word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String statusBarWordCount(int count);

  /// Status bar: how many parse notices the document raised (docs/06). Hidden when there are none.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notice} other{{count} notices}}'**
  String statusBarNotices(int count);

  /// Status bar when nothing is open, in place of path/position/word count.
  ///
  /// In en, this message translates to:
  /// **'No document open'**
  String get statusBarNoDocument;

  /// Heading of the outline panel beside the reader (docs/06).
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outlinePanelTitle;

  /// Snackbar when settings.json was corrupt or written by a newer version (docs/05).
  ///
  /// In en, this message translates to:
  /// **'Your settings could not be read. They have been kept alongside fresh defaults.'**
  String get settingsNotRestored;

  /// Outline panel when the document has no headings at all (docs/06). Not an error.
  ///
  /// In en, this message translates to:
  /// **'This document has no headings.'**
  String get outlineEmpty;

  /// Placeholder in the find bar's query field (docs/08).
  ///
  /// In en, this message translates to:
  /// **'Find in document'**
  String get findPlaceholder;

  /// Find bar: which match you are on, out of how many (docs/08).
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String findMatchCounter(int current, int total);

  /// Find bar counter when the query matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get findNoResults;

  /// Find bar: tooltip on the case-sensitivity toggle.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get findCaseSensitive;

  /// Find bar: tooltip on the next-match arrow (Enter).
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findNext;

  /// Find bar: tooltip on the previous-match arrow (Shift+Enter).
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findPrevious;

  /// Find bar: tooltip on the close button (Esc).
  ///
  /// In en, this message translates to:
  /// **'Close find'**
  String get findClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
