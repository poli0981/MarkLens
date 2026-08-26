import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/chrome.dart';
import 'package:marklens/app/documents.dart';
import 'package:marklens/app/menu/app_menu_bar.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/shortcuts.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// The application shell.
///
/// The menu bar and the full doc 06 shortcut set over the reader. File → Open
/// opens one document; the sidebar and tabs that turn that into an open *set*
/// are M1 step 6, so the panels beside the reader are still placeholders.
class MarkLensApp extends ConsumerWidget {
  /// Creates the app shell.
  const MarkLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      chromeProvider.select((state) => state.themeMode),
    );

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}

/// Menu bar, shortcut bindings, and the placeholder reader body.
class AppShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Opens the File menu on a bare `Alt`.
  ///
  /// Flutter's `MenuBar` excludes itself from focus while closed
  /// (`_MenuBarAnchorState` wraps its children in `ExcludeFocus`), so the bar
  /// cannot be highlighted-but-not-opened the way Windows does it. Alt opens
  /// the first menu instead — one keystroke rather than Alt-then-Down, and
  /// `Alt+F` / `Alt+V` / `Alt+H` still jump straight to a specific menu
  /// through the accelerator labels (spike S4).
  final MenuController _fileMenu = MenuController();

  /// Where focus returns when the menu bar is dismissed.
  final FocusNode _body = FocusNode(debugLabel: 'reader');

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// True while an `Alt` press might still turn out to be a bare `Alt` rather
  /// than the start of a combination like `Alt+F4`.
  bool _altMightBeBare = false;

  /// Watches for `Alt` pressed and released with nothing in between.
  ///
  /// This cannot be a `Shortcuts` entry: `SingleActivator` asserts that its
  /// trigger is not a modifier key, so a bare `Alt` is inexpressible there
  /// (spike S4). Doing it on key events is also what lets `Alt+F4` and friends
  /// pass through untouched — the moment any other key arrives, the press
  /// stops being a bare `Alt`.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isAlt =
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight;

    if (event is KeyDownEvent) {
      _altMightBeBare = isAlt;
      return KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) {
      // Holding Alt down is not a bare press.
      _altMightBeBare = false;
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent && isAlt && _altMightBeBare) {
      _altMightBeBare = false;
      _focusMenuBar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusMenuBar() {
    // Alt is a toggle: pressing it again closes the menu and hands focus back
    // to the reader, so Alt is never a one-way trip.
    if (_fileMenu.isOpen) {
      _fileMenu.close();
      _body.requestFocus();
    } else {
      _fileMenu.open();
    }
  }

  /// File → Open Files.
  ///
  /// Opens the first document chosen. Opening several at once needs tabs,
  /// which are M1 step 6; until then the rest are ignored rather than
  /// silently replacing each other.
  Future<void> _openFiles() async {
    final files = ref.read(fileServiceProvider);
    final paths = await ref
        .read(filePickerPromptProvider)
        .pickDocuments(files.registry);
    if (!mounted || paths.isEmpty) {
      return;
    }

    ref.read(activeDocumentProvider.notifier).open(paths.first);
    final failed = ref.read(activeDocumentProvider).failedPath;
    if (failed != null && mounted) {
      _notify(
        AppLocalizations.of(
          context,
        ).readerOpenFailed(ExtensionRegistry.basenameOf(failed)),
      );
    }
  }

  /// File → Copy entire document.
  ///
  /// Copies `rawSource` — the file as decoded, front matter included — rather
  /// than the string handed to the renderer, which has the front matter lifted
  /// out and block HTML rewritten (`docs/06_UI_UX.md`).
  Future<void> _copyDocument() async {
    final doc = ref.read(activeDocumentProvider).doc;
    if (doc == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: doc.rawSource));
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chrome = ref.watch(chromeProvider);
    final controller = ref.read(chromeProvider.notifier);

    return Shortcuts(
      shortcuts: appShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          FocusMenuBarIntent: CallbackAction<FocusMenuBarIntent>(
            onInvoke: (_) {
              _focusMenuBar();
              return null;
            },
          ),
          ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
            onInvoke: (_) {
              controller.toggleSidebar();
              return null;
            },
          ),
          ToggleOutlineIntent: CallbackAction<ToggleOutlineIntent>(
            onInvoke: (_) {
              controller.toggleOutline();
              return null;
            },
          ),
          ToggleFullScreenIntent: CallbackAction<ToggleFullScreenIntent>(
            onInvoke: (_) {
              controller.toggleFullScreen();
              return null;
            },
          ),
          ZoomIntent: CallbackAction<ZoomIntent>(
            onInvoke: (intent) {
              controller.zoomBy(intent.step);
              return null;
            },
          ),
          // The rest of the doc 06 inventory is bound but not yet implemented.
          // Binding them now is the point: S4 is checking that the whole set
          // reaches its actions, not that the actions do anything.
          OpenFilesIntent: CallbackAction<OpenFilesIntent>(
            onInvoke: (_) {
              unawaited(_openFiles());
              return null;
            },
          ),
          OpenFolderIntent: _todo(l10n.menuOpenFolder),
          ReloadDocumentIntent: CallbackAction<ReloadDocumentIntent>(
            onInvoke: (_) {
              ref.read(activeDocumentProvider.notifier).reload();
              return null;
            },
          ),
          CopyDocumentIntent: CallbackAction<CopyDocumentIntent>(
            onInvoke: (_) {
              unawaited(_copyDocument());
              return null;
            },
          ),
          CloseTabIntent: _todo(l10n.menuCloseTab),
          ReopenTabIntent: _todo(l10n.menuCloseTab),
          CycleTabIntent: _todo(l10n.menuFile),
          QuickSwitcherIntent: _todo(l10n.menuFile),
          FindInFileIntent: _todo(l10n.menuFile),
          FindAcrossFilesIntent: _todo(l10n.menuFile),
          OpenSettingsIntent: _todo(l10n.menuSettings),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Scaffold(
            body: Column(
              children: <Widget>[
                if (!chrome.fullScreen)
                  AppMenuBar(fileMenuController: _fileMenu),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      if (chrome.sidebarVisible)
                        const _Panel(label: 'Sidebar', width: 220),
                      Expanded(
                        child: Focus(
                          focusNode: _body,
                          child: _Body(zoom: chrome.zoom),
                        ),
                      ),
                      if (chrome.outlineVisible)
                        const _Panel(label: 'Outline', width: 200),
                    ],
                  ),
                ),
                _StatusBar(chrome: chrome),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Action<Intent> _todo(String item) => CallbackAction<Intent>(
    onInvoke: (_) {
      _notify(AppLocalizations.of(context).menuNotImplemented(item));
      return null;
    },
  );
}

/// The reading surface, or the empty state when nothing is open.
class _Body extends ConsumerWidget {
  const _Body({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDocumentProvider);
    final doc = active.doc;

    if (doc == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).emptyStateDropHint,
          textAlign: TextAlign.center,
          textScaler: TextScaler.linear(zoom),
        ),
      );
    }
    return ReaderView(doc: doc, zoom: zoom);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(12),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.chrome});

  final ChromeState chrome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        'zoom ${(chrome.zoom * 100).round()}%  ·  '
        'sidebar ${chrome.sidebarVisible ? 'on' : 'off'}  ·  '
        'outline ${chrome.outlineVisible ? 'on' : 'off'}  ·  '
        'theme ${chrome.themeMode.name}'
        '${chrome.fullScreen ? '  ·  full screen' : ''}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
