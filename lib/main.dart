import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';

/// Bootstraps MarkLens.
///
/// CLI argument parsing, single-instance forwarding and window geometry
/// restore land at M1 (`docs/03_DATA_FLOW.md`). What already holds here is the
/// ordering that matters: Flutter plugins are resolved once, at the top, and
/// their results are injected downward — `core/` never reaches for them
/// itself (CLAUDE.md rule 3).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configDirectory = await resolveConfigDirectory();

  runApp(
    ProviderScope(
      overrides: [
        configDirectoryProvider.overrideWithValue(configDirectory),
      ],
      child: const MarkLensApp(),
    ),
  );
}
