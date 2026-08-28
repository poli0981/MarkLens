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
import 'package:marklens/features/outline/outline_panel.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/features/search/find_bar.dart';
import 'package:marklens/features/sidebar/sidebar_tree.dart';
import 'package:marklens/features/status/status_bar.dart';
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
    // The theme is a setting, not chrome: it belongs in `settings.json`, and
    // doc 05 has always said so (`docs/05_SESSION_AND_SETTINGS.md`).
    final themeMode = ref
        .watch(settingsProvider.select((settings) => settings.theme))
        .mode;

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

    // Doc 03's "scroll settle" session trigger, and the first caller
    // `recordScroll` has ever had.
    ref.read(readerScrollProvider).onScrollSettled = (identity, ratio) =>
        ref.read(openSetProvider.notifier).recordScroll(identity, ratio);

    ref.read(watchCoordinatorProvider).start();

    if (!mounted) {
      return;
    }
    // Doc 05 asks for a one-time notice when either file could not be read.
    // `SettingsStore` has always reported it and nothing ever looked, so a
    // quarantined settings.json used to be completely silent.
    final l10n = AppLocalizations.of(context);
    final settingsOutcome = ref.read(settingsProvider.notifier).loadOutcome;
    final notices = <String>[
      if (_unreadable(outcome)) l10n.sessionNotRestored,
      if (_unreadable(settingsOutcome)) l10n.settingsNotRestored,
    ];
    if (notices.isNotEmpty) {
      // Queued rather than replaced: when both files are bad, hearing about
      // one of them is worse than hearing about neither.
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      for (final notice in notices) {
        messenger.showSnackBar(SnackBar(content: Text(notice)));
      }
    }
    session.save();
  }

  /// Whether a load outcome means the file was set aside rather than read.
  static bool _unreadable(JsonLoadOutcome outcome) =>
      outcome == JsonLoadOutcome.corrupt ||
      outcome == JsonLoadOutcome.futureVersion;

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

  /// The cheap mtime sweep of `docs/03_DATA_FLOW.md`, which covers whatever
  /// the watcher missed — and is the whole story when watching is off.
  @override
  void onWindowFocus() => ref.read(watchCoordinatorProvider).sweep();

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
              // The chrome collapsing is only half of it; the window has to be
              // told too, or F11 just hides the menu bar.
              unawaited(
                ref
                    .read(windowLinkProvider)
                    .setFullScreen(full: ref.read(chromeProvider).fullScreen),
              );
              return null;
            },
          ),
          ZoomIntent: CallbackAction<ZoomIntent>(
            onInvoke: (intent) {
              ref.read(settingsProvider.notifier).zoomBy(intent.step);
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
          FindInFileIntent: CallbackAction<FindInFileIntent>(
            onInvoke: (_) {
              ref.read(findProvider.notifier).open();
              return null;
            },
          ),
          QuickSwitcherIntent: _todo(l10n.menuFile),
          FindAcrossFilesIntent: _todo(l10n.menuFile),
          OpenSettingsIntent: _todo(l10n.menuSettings),
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Scaffold(
            body: Column(
              // Without this the column centres its children, and the menu bar
              // is the only one that shrink-wraps — Material's MenuBar declares
              // no minimum width — so it floated in the middle of the window
              // while everything else filled. Doc 06's layout diagram puts it
              // at the left, which is where a stretched box leaves it.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!chrome.fullScreen)
                  AppMenuBar(fileMenuController: _fileMenu),
                const TabStrip(),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      if (chrome.sidebarVisible)
                        SizedBox(
                          // The restored width, not a hardcoded one: the
                          // session stores it and doc 05 clamps it, and the
                          // shell used to ignore both.
                          width: chrome.sidebarWidth,
                          child: const SidebarTree(),
                        ),
                      Expanded(
                        child: Focus(
                          focusNode: _body,
                          // The bar floats over the document rather than
                          // pushing it down (doc 08): a find that reflows the
                          // page moves the very text you were looking at.
                          child: Stack(
                            children: <Widget>[
                              const Positioned.fill(child: _Body()),
                              if (ref.watch(
                                findProvider.select((find) => find.visible),
                              ))
                                const Positioned(
                                  top: 8,
                                  right: 16,
                                  child: FindBar(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (chrome.outlineVisible)
                        const SizedBox(width: 200, child: OutlinePanel()),
                    ],
                  ),
                ),
                const StatusBar(),
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
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDocumentProvider);
    final doc = active.doc;
    // Every reading preference doc 05 defines, finally reaching the reader.
    // `contentMaxWidth` and `frontMatter` had never been passed at all, so the
    // reader had been showing its constructor defaults since M1.
    final reading = ref.watch(settingsProvider.select((s) => s.reading));
    final allowRemoteImages = ref.watch(
      settingsProvider.select((s) => s.network.allowRemoteImages),
    );

    if (doc == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).emptyStateDropHint,
          textAlign: TextAlign.center,
          textScaler: TextScaler.linear(reading.fontScale),
        ),
      );
    }
    final entry = ref.watch(
      openSetProvider.select((set) => set.active),
    );
    return ReaderView(
      doc: doc,
      scroller: ref.watch(readerScrollProvider),
      identity: entry?.identity,
      restoreScroll: entry?.scroll ?? 0,
      fontScale: reading.fontScale,
      contentMaxWidth: reading.contentMaxWidth.toDouble(),
      frontMatterDisplay: reading.frontMatter,
      allowRemoteImages: allowRemoteImages,
      onLinkTap: (href) => unawaited(_follow(context, ref, href)),
    );
  }

  /// Follows a link, and says something when it went nowhere.
  ///
  /// The four cases of `docs/03_DATA_FLOW.md` are `LinkRouter`'s; what belongs
  /// here is only the part that needs a `BuildContext`. A link that worked says
  /// nothing: the reader can see that it worked.
  static Future<void> _follow(
    BuildContext context,
    WidgetRef ref,
    String href,
  ) async {
    final outcome = await ref.read(linkRouterProvider).follow(href);
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final detail = outcome.detail ?? '';
    final message = switch (outcome.kind) {
      LinkOutcomeKind.unsupported => l10n.readerLinkUnsupported(detail),
      LinkOutcomeKind.missingTarget => l10n.readerLinkMissingTarget(detail),
      LinkOutcomeKind.missingAnchor => l10n.readerLinkMissingAnchor(detail),
      LinkOutcomeKind.launchFailed => l10n.readerLinkLaunchFailed(detail),
      LinkOutcomeKind.anchor ||
      LinkOutcomeKind.document ||
      LinkOutcomeKind.external => null,
    };
    if (message == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
