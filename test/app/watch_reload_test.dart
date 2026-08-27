/// Watch events reaching the open set (`docs/03_DATA_FLOW.md`, "Watch →
/// reload").
///
/// The link is faked so the test can push a settled event by hand: real
/// watchers on a temp directory race real timers against the test binding's
/// clock, and what is being checked here is the *coordination*, not the
/// platform — `test/core/watch_service_test.dart` covers the service, and the
/// `watcher-live` tag covers the filesystem.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

class _FakeWatchLink implements WatchLink {
  final StreamController<WatchEvent> controller =
      StreamController<WatchEvent>.broadcast();

  /// Every set the coordinator asked for, in order.
  final List<({Set<String> roots, Set<String> files})> synced =
      <({Set<String> roots, Set<String> files})>[];

  int flushes = 0;

  @override
  Stream<WatchEvent> get events => controller.stream;

  @override
  void sync({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) => synced.add((roots: roots.toSet(), files: files.toSet()));

  @override
  void flush() => flushes++;

  @override
  bool get degraded => false;

  @override
  Future<void> dispose() => controller.close();
}

void main() {
  late Directory config;
  late _FakeWatchLink link;

  String at(String name) => '${config.path}${Platform.pathSeparator}$name';

  String write(String name, String contents) {
    File(at(name)).writeAsStringSync(contents);
    return at(name);
  }

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_watch_');
    link = _FakeWatchLink();
  });

  tearDown(() async {
    await link.dispose();
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        watchLinkProvider.overrideWithValue(link),
        sessionStoreProvider.overrideWithValue(
          SessionStore(
            directory: config,
            debounce: const Duration(milliseconds: 10),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  Future<void> push(WidgetTester tester, WatchEvent event) async {
    link.controller.add(event);
    await tester.pumpAndSettle();
  }

  Finder inReader(Finder matching) =>
      find.descendant(of: find.byType(ReaderView), matching: matching);

  group('a document that changed on disk', () {
    testWidgets('re-parses while it is the one being read', (tester) async {
      final path = write('doc.md', '# Before\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      expect(inReader(find.text('Before')), findsOneWidget);

      write('doc.md', '# After the edit\n');
      await push(
        tester,
        WatchEvent(path: path, kind: WatchEventKind.changed),
      );

      expect(inReader(find.text('After the edit')), findsOneWidget);
      expect(inReader(find.text('Before')), findsNothing);
    });

    testWidgets('only gets a dot while it is in the background', (
      tester,
    ) async {
      final active = write('active.md', '# Active\n');
      final other = write('other.md', '# Other\n');
      final container = await pumpShell(tester);
      // The first path opened becomes the active tab (docs/03), so this order
      // is what makes `other.md` the background one.
      container.read(openSetProvider.notifier).openPaths(<String>[
        active,
        other,
      ]);
      await tester.pumpAndSettle();

      final activeIdentity = container.read(openSetProvider).activeIdentity!;
      final otherIdentity = container
          .read(openSetProvider)
          .entries
          .firstWhere((e) => e.identity != activeIdentity)
          .identity;

      write('other.md', '# Other, edited elsewhere\n');
      await push(
        tester,
        WatchEvent(path: other, kind: WatchEventKind.changed),
      );

      expect(
        container.read(openSetProvider).entryFor(otherIdentity)!.stale,
        isTrue,
        reason: 'doc 03: a background change is a badge, not a re-parse',
      );
      expect(
        container.read(openSetProvider).entryFor(activeIdentity)!.stale,
        isFalse,
      );
    });

    testWidgets('one nobody opened is ignored', (tester) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      await push(
        tester,
        WatchEvent(
          path: at('unrelated.md'),
          kind: WatchEventKind.changed,
        ),
      );

      expect(
        container.read(openSetProvider).entries,
        hasLength(1),
        reason: 'watching a directory means hearing about every file in it',
      );
    });
  });

  group('a document that vanished', () {
    testWidgets('keeps its entry and gains the badge', (tester) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      File(path).deleteSync();
      await push(
        tester,
        WatchEvent(path: path, kind: WatchEventKind.missing),
      );

      final entry = container.read(openSetProvider).entries.single;
      expect(entry.file.missing, isTrue);
      expect(
        find.byIcon(Icons.link_off),
        findsWidgets,
        reason: 'entries leave the session only when the user closes them',
      );
    });
  });

  group('what gets watched', () {
    testWidgets('an ad-hoc file is offered as a file, not as a root', (
      tester,
    ) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      expect(link.synced.last.roots, isEmpty);
      expect(link.synced.last.files, contains(path));
    });

    testWidgets('an unrelated change to the open set does not re-sync', (
      tester,
    ) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      final before = link.synced.length;

      final identity = container.read(openSetProvider).activeIdentity!;
      container.read(openSetProvider.notifier)
        ..togglePin(identity)
        ..recordScroll(identity, 0.4);
      await tester.pumpAndSettle();

      expect(
        link.synced.length,
        before,
        reason:
            'a pin and a scroll change the open set but not which directories '
            'matter; restarting a platform watcher for them would be waste',
      );
    });

    testWidgets('turning watching off stops watching everything', (
      tester,
    ) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      container.read(settingsProvider.notifier).setWatchEnabled(enabled: false);
      await tester.pumpAndSettle();
      await tester.pump(AppSettingsController.writeDebounce);

      expect(link.synced.last.roots, isEmpty);
      expect(
        link.synced.last.files,
        isEmpty,
        reason:
            'doc 07: watching off degrades to the focus sweep, and the '
            'sweep is the whole story then',
      );
    });
  });

  group('the window-focus sweep', () {
    testWidgets('re-stats the open set and settles anything in flight', (
      tester,
    ) async {
      final path = write('doc.md', '# Doc\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      File(path).deleteSync();
      container.read(watchCoordinatorProvider).sweep();
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).entries.single.file.missing,
        isTrue,
        reason: 'doc 03: focus regained covers whatever the watcher missed',
      );
      expect(link.flushes, 1);
    });
  });
}
