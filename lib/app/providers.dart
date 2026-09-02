/// Composition root: core services are constructed here and exposed as
/// providers. Features talk to each other only through this file
/// (`docs/02_ARCHITECTURE.md`).
///
/// The app-level state a feature legitimately needs is re-exported rather than
/// redeclared, so `features/` still has exactly one door into `app/` while the
/// state itself stays in the file it belongs to.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/drop_target.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/settings_link.dart';
import 'package:marklens/app/window_link.dart';
import 'package:marklens/core/cache/doc_cache.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/files/file_service.dart';
import 'package:marklens/core/log/log_buffer.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/search/search_service.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/core/settings/settings_store.dart';
import 'package:marklens/core/single_instance.dart';
import 'package:marklens/core/update/update_service.dart';
import 'package:path_provider/path_provider.dart';

export 'package:marklens/app/chrome.dart'
    show ChromeController, ChromeState, SidebarPanel, chromeProvider;
export 'package:marklens/app/cross_search.dart'
    show CrossSearchController, CrossSearchState, crossSearchProvider;
export 'package:marklens/app/documents.dart'
    show ActiveDocument, ActiveDocumentController, activeDocumentProvider;
export 'package:marklens/app/drop_target.dart'
    show DropTargetLink, NoDropTargetLink, PlatformDropTargetLink;
export 'package:marklens/app/find.dart'
    show FindController, FindState, findProvider;
export 'package:marklens/app/launcher_link.dart'
    show
        LauncherLink,
        PlatformLauncherLink,
        RecordingLauncherLink,
        launcherLinkProvider;
export 'package:marklens/app/link_router.dart'
    show LinkOutcome, LinkOutcomeKind, LinkRouter, linkRouterProvider;
export 'package:marklens/app/open_set.dart'
    show OpenSetController, openSetProvider;
export 'package:marklens/app/reader_scroll.dart'
    show BlockScroller, readerScrollProvider;
export 'package:marklens/app/recent_files.dart'
    show RecentFiles, recentFilesProvider;
export 'package:marklens/app/save_file.dart'
    show
        PlatformSaveFilePrompt,
        SaveFilePrompt,
        StubSaveFilePrompt,
        saveFilePromptProvider;
export 'package:marklens/app/session_link.dart'
    show SessionLink, sessionLinkProvider;
export 'package:marklens/app/settings_link.dart'
    show AppSettingsController, settingsProvider;
// The font stacks, so the reader can name the bundled families without
// reaching past this door. Compile-time constants rather than app state, for
// the same reason `appVersion` is re-exported rather than wrapped in a
// provider - and the alternative was widening the architecture test's
// two-URI allowlist to dodge the door that already exists.
export 'package:marklens/app/theme/typography.dart'
    show monoFallback, monoFamily, sansFallback, sansFamily;
export 'package:marklens/app/update_banner.dart'
    show
        LastUpdateCheck,
        UpdateBannerController,
        UpdateBannerState,
        lastUpdateCheckProvider,
        updateBannerProvider;
// The version string, so About can show it without reaching past this door.
// A compile-time constant rather than app state, which is exactly why it is
// re-exported rather than wrapped in a provider.
export 'package:marklens/app/version.dart' show appVersion;
export 'package:marklens/app/watch_coordinator.dart'
    show WatchCoordinator, watchCoordinatorProvider;
export 'package:marklens/app/watch_link.dart'
    show NoWatchLink, PlatformWatchLink, WatchLink, watchLinkProvider;
export 'package:marklens/app/window_link.dart'
    show
        NoWindowLink,
        PlatformWindowLink,
        WindowGeometryController,
        WindowLink,
        windowGeometryProvider;

/// The app's own config directory — `session.json` and `settings.json` live
/// here, and it is the only place MarkLens ever writes (CLAUDE.md rule 1).
///
/// Overridden in `main()` with the value from [resolveConfigDirectory]. It is
/// a provider rather than a direct `path_provider` call inside the stores
/// because `path_provider` is a Flutter plugin and `core/` is pure Dart
/// (rule 3) — the stores take this `Directory` as a constructor argument,
/// which also lets tests hand them a temp directory with no mocking.
final Provider<Directory> configDirectoryProvider = Provider<Directory>(
  (ref) => throw StateError(
    'configDirectoryProvider must be overridden in main() or in a test',
  ),
);

/// Reads and writes `settings.json` (`docs/05_SESSION_AND_SETTINGS.md`).
final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(directory: ref.watch(configDirectoryProvider)),
);

/// Reads and writes `session.json`, debounced (rule 7).
///
/// Disposed with the scope, which flushes whatever write was still pending.
/// That covers an in-process teardown — a test's container — and **not** a
/// real exit, where the process ends with the window and the scope is never
/// disposed at all. Quitting is `ShutdownSequence`'s, which flushes this
/// explicitly (`docs/03_DATA_FLOW.md`, "App exit").
final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>((
  ref,
) {
  final store = SessionStore(directory: ref.watch(configDirectoryProvider));
  ref.onDispose(store.dispose);
  return store;
});

/// Finds the documents MarkLens will open (`docs/07_FILES_AND_WATCH.md`).
///
/// Built **from the settings**, which is what `files.extensions` and
/// `files.fileCap` were always for and what neither had until M3. It watches
/// only those two fields, so a zoom step does not rebuild the file service —
/// and when they do change, every caller gets the new registry on its next
/// read, because that is what a `Provider` dependency means.
final Provider<FileService> fileServiceProvider = Provider<FileService>((ref) {
  final files = ref.watch(settingsProvider.select((s) => s.files));
  return FileService(
    registry: ExtensionRegistry(files.extensions),
    fileCap: files.fileCap,
  );
});

/// Files dropped onto the window (`docs/03_DATA_FLOW.md`).
///
/// Overridden with [NoDropTargetLink] in widget tests: `desktop_drop` has no
/// platform channel there, and what a drop resolves to — `openPaths` — is
/// driven directly instead.
final Provider<DropTargetLink> dropTargetProvider = Provider<DropTargetLink>(
  (ref) => const PlatformDropTargetLink(),
);

/// The in-memory diagnostic log (`docs/02_ARCHITECTURE.md`, "Logging").
///
/// One buffer for the whole app, and the only thing that ever leaves it is
/// Help → Export Diagnostic Log, to a file the reader points at.
final Provider<LogBuffer> logBufferProvider = Provider<LogBuffer>(
  (ref) => LogBuffer(),
);

/// The GitHub Releases tag check (`docs/11_PACKAGING_UPDATE.md`).
///
/// A provider so a widget test can hand over a transport that answers without
/// a socket — real network I/O inside `testWidgets` stalls against the test
/// binding's clock, the same trap real sockets were at M1.
final Provider<UpdateService> updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(),
);

/// Scans the open set from disk, in an isolate (`docs/08_SEARCH.md`).
///
/// A provider so a test can hand the panel a service that answers without
/// spawning anything: an isolate inside `testWidgets` runs against real time
/// while the binding drives a fake clock, which is the same trap real sockets
/// were at M1.
final Provider<SearchService> searchServiceProvider = Provider<SearchService>(
  (ref) => const SearchService(),
);

/// The LRU of parsed documents (CLAUDE.md rule 8).
final Provider<DocCache> docCacheProvider = Provider<DocCache>(
  (ref) => DocCache(),
);

/// Coordinates second launches (`docs/03_DATA_FLOW.md`).
///
/// Overridden in `main()` with the instance that already acquired the lock, so
/// the app never has two of them; a test that does not care overrides it with
/// one pointed at a temp directory.
final Provider<SingleInstance> singleInstanceProvider =
    Provider<SingleInstance>(
      (ref) => SingleInstance(directory: ref.watch(configDirectoryProvider)),
    );

/// Paths handed over by later launches (`docs/03_DATA_FLOW.md`).
///
/// A provider of its own rather than a reach into [singleInstanceProvider], so
/// a widget test can push paths through the shell without binding a real
/// socket — real I/O inside `testWidgets` stalls against the test binding's
/// clock. The socket itself is covered by `test/core/single_instance_test.dart`,
/// where it belongs.
final Provider<Stream<List<String>>> forwardedPathsProvider =
    Provider<Stream<List<String>>>(
      (ref) => ref.watch(singleInstanceProvider).forwardedPaths,
    );

/// Everything MarkLens asks of the real window.
///
/// Overridden with `NoWindowLink` in widget tests: `window_manager` has no
/// platform channel there, and some of its calls return a future that never
/// completes rather than failing.
final Provider<WindowLink> windowLinkProvider = Provider<WindowLink>(
  (ref) => const PlatformWindowLink(),
);

/// Files and folders named on the command line at this launch.
final Provider<List<String>> launchPathsProvider = Provider<List<String>>(
  (ref) => const <String>[],
);

/// Asks the user for documents to open.
///
/// Overridden in widget tests with a stub, so the shell can be driven without
/// a platform dialog.
final Provider<FilePickerPrompt> filePickerPromptProvider =
    Provider<FilePickerPrompt>((ref) => const PlatformFilePickerPrompt());

/// The one path from a file's bytes to a `DocModel`
/// (`docs/04_MARKDOWN_PIPELINE.md`).
final Provider<MarkdownPipeline> markdownPipelineProvider =
    Provider<MarkdownPipeline>((ref) => const MarkdownPipeline());

/// Resolves the config directory without creating it.
///
/// Creation is deferred to the first store write, so simply launching the app
/// touches no disk (`docs/05_SESSION_AND_SETTINGS.md`).
Future<Directory> resolveConfigDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}marklens');
}
