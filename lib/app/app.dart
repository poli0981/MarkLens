import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/menu/app_menu_bar.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/shortcuts.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/storage/json_store.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/features/sidebar/sidebar_tree.dart';
import 'package:marklens/features/tabs/tab_strip.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

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

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
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

  StreamSubscription<List<String>>? _forwarded;

  @override
  void initState() {
    super.initState();
    // The cold-start order of docs/03: session first, then anything the
    // command line named, so a launch that opens a file lands on that file
    // rather than on whatever was open last time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _coldStart());
  }

  Future<void> _coldStart() async {
    final session = ref.read(sessionLinkProvider);
    final outcome = session.restore();

    final window = ref.read(windowLinkProvider);
    await window.restore(ref.read(windowGeometryProvider));
    await window.attach(this);

    final launchPaths = ref.read(launchPathsProvider);
    if (launchPaths.isNotEmpty) {
      ref.read(openSetProvider.notifier).openPaths(launchPaths);
    }

    // A second launch hands its arguments over rather than starting a rival
    // window (docs/03). They are treated exactly like command-line paths.
    _forwarded = ref.read(forwardedPathsProvider).listen(_onForwarded);

    if (!mounted) {
      return;
    }
    if (outcome == JsonLoadOutcome.corrupt ||
        outcome == JsonLoadOutcome.futureVersion) {
      _notify(AppLocalizations.of(context).sessionNotRestored);
    }
    session.save();
  }

  void _onForwarded(List<String> paths) {
    ref.read(openSetProvider.notifier).openPaths(paths);
    unawaited(ref.read(windowLinkProvider).focus());
  }

  @override
  void onWindowMoved() => unawaited(_recordGeometry());

  @override
  void onWindowResized() => unawaited(_recordGeometry());

  @override
  void onWindowMaximize() => unawaited(_recordGeometry());

  @override
  void onWindowUnmaximize() => unawaited(_recordGeometry());

  @override
  void onWindowClose() => unawaited(_shutDown());

  Future<void> _recordGeometry() async {
    final geometry = await ref.read(windowLinkProvider).current();
    if (geometry == null || !mounted) {
      return;
    }
    ref.read(windowGeometryProvider.notifier).geometry = geometry;
    ref.read(sessionLinkProvider).save();
  }

  /// Writes the session and lets go of the lock before the window goes.
  Future<void> _shutDown() async {
    await _recordGeometry();
    ref.read(sessionLinkProvider).flush();
    await ref.read(singleInstanceProvider).release();
    await ref.read(windowLinkProvider).detachAndClose(this);
  }

  @override
  void dispose() {
    unawaited(_forwarded?.cancel());
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
  /// Everything chosen is opened; the first becomes the active tab
  /// (`docs/03_DATA_FLOW.md`).
  Future<void> _openFiles() async {
    final files = ref.read(fileServiceProvider);
    final paths = await ref
        .read(filePickerPromptProvider)
        .pickDocuments(files.registry);
    if (!mounted || paths.isEmpty) {
      return;
    }

    // A path that is not a readable file never reaches the open set at all,
    // so the count is the only way to tell that something the user picked did
    // not open.
    final resolved = ref.read(openSetProvider.notifier).openPaths(paths);
    if (resolved < paths.length && mounted) {
      _notify(
        AppLocalizations.of(
          context,
        ).readerOpenFailed(ExtensionRegistry.basenameOf(paths.first)),
      );
    }
  }

  /// File → Open Folder.
  ///
  /// A scan over the cap opens nothing and asks first — doc 07 is explicit
  /// that a folder is never silently truncated.
  Future<void> _openFolder() async {
    final root = await ref.read(filePickerPromptProvider).pickFolder();
    if (!mounted || root == null) {
      return;
    }

    final openSet = ref.read(openSetProvider.notifier)..openFolder(root);
    final capped = ref.read(openSetProvider).capExceededRoot;
    if (capped == null || !mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final cap = ref.read(fileServiceProvider).fileCap;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.openFolderCapTitle(cap)),
        content: Text(l10n.openFolderCapBody(cap)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.openFolderCapAccept(cap)),
          ),
        ],
      ),
    );

    if (accepted ?? false) {
      openSet.acceptCappedScan();
    } else {
      openSet.cancelCappedScan();
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

    // The session-save triggers of docs/03: a tab opening, closing or
    // switching, a pin, a scroll settling, a panel toggling. Every one of them
    // shows up as a change to one of these two, and the store coalesces a
    // second of them into a single write (rule 7), so listening broadly here
    // costs nothing and forgetting a trigger costs the session.
    ref
      ..listen(openSetProvider, (_, _) => ref.read(sessionLinkProvider).save())
      ..listen(chromeProvider, (_, _) => ref.read(sessionLinkProvider).save());

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
          OpenFilesIntent: CallbackAction<OpenFilesIntent>(
            onInvoke: (_) {
              unawaited(_openFiles());
              return null;
            },
          ),
          OpenFolderIntent: CallbackAction<OpenFolderIntent>(
            onInvoke: (_) {
              unawaited(_openFolder());
              return null;
            },
          ),
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
          CloseTabIntent: CallbackAction<CloseTabIntent>(
            onInvoke: (_) {
              final active = ref.read(openSetProvider).activeIdentity;
              if (active != null) {
                ref.read(openSetProvider.notifier).close(active);
              }
              return null;
            },
          ),
          ReopenTabIntent: CallbackAction<ReopenTabIntent>(
            onInvoke: (_) {
              ref.read(openSetProvider.notifier).reopenClosed();
              return null;
            },
          ),
          CycleTabIntent: CallbackAction<CycleTabIntent>(
            onInvoke: (intent) {
              ref.read(openSetProvider.notifier).cycle(intent.forward ? 1 : -1);
              return null;
            },
          ),
          // The rest of the doc 06 inventory is bound but not yet implemented.
          // Binding them keeps the whole set reachable (spike S4).
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
                const TabStrip(),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      if (chrome.sidebarVisible)
                        const SizedBox(width: 240, child: SidebarTree()),
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
