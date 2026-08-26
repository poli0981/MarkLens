/// `docs/03_DATA_FLOW.md` cold start and session save, end to end: what was
/// open comes back, what the command line names is added, and a second launch
/// hands over instead of starting a rival window.
///
/// This is the M1 gate in test form. It goes through the real shell, the real
/// stores and real files; only the file dialog is stubbed, because it is a
/// platform plugin.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/session/session_store.dart';

class _NoPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;
  late Directory config;
  late File alpha;
  late File beta;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_session_e2e_');
    config = Directory('${root.path}${Platform.pathSeparator}config');
    alpha = File(at('alpha.md'))..writeAsStringSync('# Alpha\n');
    beta = File(at('beta.md'))..writeAsStringSync('# Beta\n');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<String> launchPaths = const <String>[],
    Stream<List<String>>? forwarded,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        filePickerPromptProvider.overrideWithValue(_NoPrompt()),
        launchPathsProvider.overrideWithValue(launchPaths),
        // No platform channel in a widget test, and some window_manager calls
        // return a future that never completes there — which hangs
        // pumpAndSettle rather than failing.
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        // A short debounce, so a test does not have to wait a real second for
        // the write — and so no timer is left pending when it ends. The
        // one-second default is asserted in session_store_test.
        sessionStoreProvider.overrideWithValue(
          SessionStore(
            directory: config,
            debounce: const Duration(milliseconds: 10),
          ),
        ),
        if (forwarded != null)
          forwardedPathsProvider.overrideWithValue(forwarded),
      ],
    );
    addTearDown(container.dispose);

    // A blank frame first. Pumping MarkLensApp twice in one test would reuse
    // the element tree — same widget type, same position — so `initState`
    // would not run again and cold start would be skipped, which is exactly
    // the thing under test here.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Let the cold-start save land rather than leaving its timer pending.
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  group('a session comes back', () {
    testWidgets('what was open, in order, with the active one active', (
      tester,
    ) async {
      final opened = await pumpApp(tester);
      opened.read(openSetProvider.notifier)
        ..openPaths(<String>[alpha.path, beta.path])
        ..togglePin(opened.read(openSetProvider).entries.last.identity);
      opened.read(sessionLinkProvider)
        ..save()
        ..flush();

      final restored = await pumpApp(tester);
      final set = restored.read(openSetProvider);

      expect(set.entries.map((e) => e.file.name), <String>[
        'alpha.md',
        'beta.md',
      ]);
      expect(set.active!.file.name, 'alpha.md');
      expect(set.entries.last.pinned, isTrue);
      expect(
        find.textContaining('Alpha', findRichText: true),
        findsWidgets,
        reason: 'the active document is parsed and drawn on cold start',
      );
    });

    testWidgets('a scroll position survives', (tester) async {
      final opened = await pumpApp(tester);
      opened.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      final identity = opened.read(openSetProvider).entries.single.identity;
      opened.read(openSetProvider.notifier).recordScroll(identity, 0.6);
      opened.read(sessionLinkProvider)
        ..save()
        ..flush();

      final restored = await pumpApp(tester);
      expect(restored.read(openSetProvider).entries.single.scroll, 0.6);
    });

    testWidgets('a file deleted between runs is kept and badged', (
      tester,
    ) async {
      final opened = await pumpApp(tester);
      opened.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      opened.read(sessionLinkProvider)
        ..save()
        ..flush();
      alpha.deleteSync();

      final restored = await pumpApp(tester);
      final entry = restored.read(openSetProvider).entries.single;

      expect(entry.file.missing, isTrue);
      expect(
        restored.read(activeDocumentProvider).hasDocument,
        isFalse,
        reason: 'there is nothing to render, but the tab stays (docs/07)',
      );
    });

    testWidgets('a first run restores nothing and says nothing', (
      tester,
    ) async {
      final fresh = await pumpApp(tester);
      expect(fresh.read(openSetProvider).isEmpty, isTrue);
      expect(find.textContaining('could not be read'), findsNothing);
    });

    testWidgets('a corrupt session starts empty and says so once', (
      tester,
    ) async {
      config.createSync(recursive: true);
      File(
        '${config.path}${Platform.pathSeparator}session.json',
      ).writeAsStringSync('{ truncated');

      final container = await pumpApp(tester);

      expect(container.read(openSetProvider).isEmpty, isTrue);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(
        config.listSync().where((e) => e.path.contains('corrupt-')),
        hasLength(1),
        reason: 'the evidence is kept, not deleted (docs/05)',
      );
    });
  });

  group('the command line', () {
    testWidgets('opens what it names, on top of the session', (tester) async {
      final opened = await pumpApp(tester);
      opened.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      opened.read(sessionLinkProvider)
        ..save()
        ..flush();

      final relaunched = await pumpApp(
        tester,
        launchPaths: <String>[beta.path],
      );
      final set = relaunched.read(openSetProvider);

      expect(set.entries.map((e) => e.file.name), <String>[
        'alpha.md',
        'beta.md',
      ]);
      expect(
        set.active!.file.name,
        'beta.md',
        reason:
            'a launch that names a file should land on that file, not on '
            'whatever was open last time',
      );
    });

    testWidgets('a path it names that is gone is simply not opened', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        launchPaths: <String>[at('nowhere.md')],
      );
      expect(container.read(openSetProvider).isEmpty, isTrue);
    });
  });

  group('a second launch hands over', () {
    testWidgets('forwarded paths become tabs in the running window', (
      tester,
    ) async {
      // The socket itself is covered in single_instance_test; what matters
      // here is that whatever it hands over reaches the open set.
      final forwarded = StreamController<List<String>>.broadcast();
      addTearDown(forwarded.close);

      final container = await pumpApp(tester, forwarded: forwarded.stream);
      expect(container.read(openSetProvider).isEmpty, isTrue);

      forwarded.add(<String>[beta.path]);
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).entries.map((e) => e.file.name),
        <String>['beta.md'],
        reason: 'a second launch adds a tab rather than a rival window',
      );
      expect(
        container.read(openSetProvider).active!.file.name,
        'beta.md',
        reason: 'and it lands on what the second launch asked for',
      );
    });
  });

  group('saving happens on the doc 03 triggers', () {
    testWidgets('opening a tab is enough — no explicit save needed', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      // Only time passes. This is the gap that let a forwarded path reach the
      // window and never reach session.json.
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(sessionStoreProvider).load().state.documents,
        hasLength(1),
      );
    });

    testWidgets('closing a tab is too', (tester) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      await tester.pump(const Duration(milliseconds: 50));

      container
          .read(openSetProvider.notifier)
          .close(
            container.read(openSetProvider).entries.single.identity,
          );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(sessionStoreProvider).load().state.documents,
        isEmpty,
      );
    });

    testWidgets('toggling a panel is too', (tester) async {
      final container = await pumpApp(tester);
      container.read(chromeProvider.notifier).toggleOutline();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(sessionStoreProvider).load().state.outlineVisible,
        isFalse,
      );
    });
  });

  group('the session file itself', () {
    testWidgets('is written atomically, with its schema version', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[alpha.path]);
      container.read(sessionLinkProvider)
        ..save()
        ..flush();

      final names = config
          .listSync()
          .map((e) => e.path.split(RegExp(r'[/\\]')).last)
          .toList();
      expect(
        names,
        isNot(contains('session.json.tmp')),
        reason: 'the temp file is renamed over the target, never left behind',
      );

      final loaded = container.read(sessionStoreProvider).load();
      expect(loaded.state.documents, hasLength(1));
      expect(SessionState.schemaVersion, 1);
    });
  });
}
