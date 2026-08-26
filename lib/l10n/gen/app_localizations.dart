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

  /// Snackbar shown when a prototype menu item has no behaviour yet.
  ///
  /// In en, this message translates to:
  /// **'{item} is not wired up yet'**
  String menuNotImplemented(String item);

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
