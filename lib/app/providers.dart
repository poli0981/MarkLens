import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Composition root: core services are constructed here and exposed as
/// providers. Features talk to each other only through this file
/// (`docs/02_ARCHITECTURE.md`).

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

/// Resolves the config directory without creating it.
///
/// Creation is deferred to the first store write, so simply launching the app
/// touches no disk (`docs/05_SESSION_AND_SETTINGS.md`).
Future<Directory> resolveConfigDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}marklens');
}
