/// The shell's exit, end to end through the real stores
/// (`docs/03_DATA_FLOW.md`, "App exit"): what reaches the disk before the
/// window goes, and what is asked to stop first.
///
/// The window is a recorder rather than `NoWindowLink`, because `NoWindowLink`
/// never hands the shell's listener back and so `onWindowClose` was never
/// reachable from a test — which is how a settings change in the last quarter
/// second before quitting could be lost for a whole release.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:window_manager/window_manager.dart';

class _NoPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

/// A window that remembers who attached, so the test can close it.
class _RecordingWindowLink implements WindowLink {
  _RecordingWindowLink(this.order);

  final List<String> order;
  WindowListener? listener;
  int closed = 0;

  static const WindowGeometry geometry = WindowGeometry(
    x: 10,
    y: 20,
    width: 800,
    height: 600,
  );

  @override
  Future<void> prepare() async {}

  @override
  Future<void> restore(WindowGeometry? geometry) async {}

  @override
  Future<WindowGeometry?> current() async => geometry;

  @override
  Future<void> attach(WindowListener listener) async =>
      this.listener = listener;

  @override
  Future<void> detachAndClose(WindowListener listener) async {
    closed++;
    order.add('window.detachAndClose');
  }

  @override
  Future<void> focus() async {}

  @override
  Future<void> setFullScreen({required bool full}) async {}

  @override
  Future<void> requestClose() async {}
}

class _RecordingWatchLink implements WatchLink {
  _RecordingWatchLink(this.order, {this.hang = false});

  final List<String> order;
  final bool hang;
  int disposed = 0;

  @override
  Stream<WatchEvent> get events => const Stream<WatchEvent>.empty();

  @override
  void sync({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) {}

  @override
  void flush() {}

  @override
  bool get degraded => false;

  @override
  Future<void> dispose() {
    disposed++;
    order.add('watch.dispose');
    return hang ? Completer<void>().future : Future<void>.value();
  }
}

void main() {
  late Directory root;
  late Directory config;
  late File alpha;
  late List<String> order;
  late _RecordingWindowLink window;
  late _RecordingWatchLink watch;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';
  File configFile(String name) =>
      File('${config.path}${Platform.pathSeparator}$name');

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_exit_');
    config = Directory('${root.path}${Platform.pathSeparator}config');
    alpha = File(at('alpha.md'))..writeAsStringSync('# Alpha\n');
    order = <String>[];
    window = _RecordingWindowLink(order);
    watch = _RecordingWatchLink(order);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        filePickerPromptProvider.overrideWithValue(_NoPrompt()),
        windowLinkProvider.overrideWithValue(window),
        watchLinkProvider.overrideWithValue(watch),
        sessionStoreProvider.overrideWithValue(
          SessionStore(
            directory: config,
            debounce: const Duration(milliseconds: 10),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// Lets the sequence run through its awaits.
  ///
  /// Time has to pass, not just frames: the sequence yields one turn of the
  /// event loop after the watchers, and a zero-length timer under the test
  /// binding's fake clock fires only when the clock moves.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  /// Closes the window the way the title-bar button does.
  Future<void> close(WidgetTester tester) async {
    window.listener!.onWindowClose();
    await settle(tester);
  }

  testWidgets('a setting changed just before exit reaches the disk', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container.read(settingsProvider.notifier).setFontScale(1.3);
    // Not pumped past `writeDebounce`: the change is still inside its
    // coalescing window when the close arrives. Until v1.0.1 it was lost.
    await close(tester);

    final written = jsonDecode(
      configFile('settings.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect((written['reading']! as Map<String, Object?>)['fontScale'], 1.3);
  });

  testWidgets('the session is written, with the window where it was', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
    await close(tester);

    final session = container.read(sessionStoreProvider).load().state;
    expect(session.documents.map((d) => d.path), <String>[alpha.path]);
    expect(session.window?.x, _RecordingWindowLink.geometry.x);
    expect(session.window?.height, _RecordingWindowLink.geometry.height);
  });

  testWidgets('the watchers are asked to stop before the window goes', (
    tester,
  ) async {
    await pumpApp(tester);
    await close(tester);

    expect(watch.disposed, 1);
    expect(
      order.indexOf('watch.dispose'),
      lessThan(order.indexOf('window.detachAndClose')),
    );
  });

  testWidgets('a second close joins the first', (tester) async {
    await pumpApp(tester);
    window.listener!.onWindowClose();
    window.listener!.onWindowClose();
    await settle(tester);

    expect(window.closed, 1);
    expect(watch.disposed, 1);
  });

  testWidgets('a watcher that never answers does not hold the exit', (
    tester,
  ) async {
    watch = _RecordingWatchLink(order, hang: true);
    await pumpApp(tester);
    window.listener!.onWindowClose();
    await tester.pump(const Duration(milliseconds: 500));
    expect(window.closed, 0, reason: 'still waiting on the watcher');

    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(window.closed, 1);
    expect(
      order.last,
      'window.detachAndClose',
      reason: 'the bound fired and the exit went on (docs/03)',
    );
  });
}
