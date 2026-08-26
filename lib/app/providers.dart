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
import 'package:marklens/app/open_files.dart';
import 'package:marklens/core/cache/doc_cache.dart';
import 'package:marklens/core/files/file_service.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/core/settings/settings_store.dart';
import 'package:path_provider/path_provider.dart';

export 'package:marklens/app/chrome.dart'
    show ChromeController, ChromeState, chromeProvider;
export 'package:marklens/app/documents.dart'
    show ActiveDocument, ActiveDocumentController, activeDocumentProvider;
export 'package:marklens/app/open_set.dart'
    show OpenSetController, openSetProvider;

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
/// Disposed with the scope, which flushes whatever write was still pending —
/// quitting must not lose the last second of a session.
final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>((
  ref,
) {
  final store = SessionStore(directory: ref.watch(configDirectoryProvider));
  ref.onDispose(store.dispose);
  return store;
});

/// Finds the documents MarkLens will open (`docs/07_FILES_AND_WATCH.md`).
///
/// Constructed with the defaults for now. Rebuilding it from
/// `files.extensions` and `files.fileCap` belongs with the Settings UI, where
/// there is something that can change them (M3, doc 15).
final Provider<FileService> fileServiceProvider = Provider<FileService>(
  (ref) => const FileService(),
);

/// The LRU of parsed documents (CLAUDE.md rule 8).
final Provider<DocCache> docCacheProvider = Provider<DocCache>(
  (ref) => DocCache(),
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
