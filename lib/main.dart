import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/version.dart';
import 'package:marklens/core/cli/launch_arguments.dart';
import 'package:marklens/core/single_instance.dart';

/// Bootstraps MarkLens.
///
/// The order is `docs/03_DATA_FLOW.md`'s cold start, and it is the order for a
/// reason: arguments are parsed before anything is created so `--help` costs
/// nothing, single-instance is settled before any state is touched so a second
/// launch never opens a store it is about to abandon, and Flutter plugins are
/// resolved once at the top and injected downward — `core/` never reaches for
/// them itself (CLAUDE.md rule 3).
Future<void> main(List<String> argv) async {
  final launch = parseLaunchArguments(argv);

  // These three exit the process rather than returning. On Windows the native
  // runner has already created its window and started a message loop by the
  // time Dart `main` runs, so returning here would print and then sit there as
  // a blank window — measured, not assumed.
  if (launch.error != null) {
    stderr
      ..writeln('marklens: ${launch.error}')
      ..writeln(launchUsage());
    exit(64); // EX_USAGE
  }
  if (launch.help) {
    stdout.writeln(launchUsage());
    exit(0);
  }
  if (launch.version) {
    stdout.writeln('MarkLens $appVersion');
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();

  final configDirectory = await resolveConfigDirectory();
  final instance = SingleInstance(directory: configDirectory);

  if (await instance.acquire(launch.paths) == InstanceRole.handedOver) {
    // The running window has the paths now. Leaving quietly is the whole point
    // — a second process would fight the first over one session.json — and it
    // has to be `exit`, for the same reason as above.
    exit(0);
  }

  try {
    await const PlatformWindowLink().prepare();
  } on Object {
    // No window manager: the app still runs, just without geometry restore.
  }

  runApp(
    ProviderScope(
      overrides: [
        configDirectoryProvider.overrideWithValue(configDirectory),
        singleInstanceProvider.overrideWithValue(instance),
        launchPathsProvider.overrideWithValue(launch.paths),
      ],
      child: const MarkLensApp(),
    ),
  );
}
