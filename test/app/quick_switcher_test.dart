/// `docs/08_SEARCH.md`, `Ctrl+P`, and the recent list all three of its
/// surfaces read.
///
/// The scoring itself is `test/core/fuzzy_test.dart`. What is asserted here is
/// what only exists once it is wired: that the switcher lists open files *and*
/// closed ones, that arrows and Enter work, and that "recent" survives a close
/// — which it did not before M3, because the list was derived from the open
/// set and so could only ever contain files that were open.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/search/quick_switcher.dart';

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_switcher_');
    for (final name in <String>[
      'README.md',
      'ARCHITECTURE.md',
      'random-numbers.md',
    ]) {
      File(at(name)).writeAsStringSync('# $name\n');
    }
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<String> open = const <String>['README.md', 'ARCHITECTURE.md'],
  }) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          filePickerPromptProvider.overrideWithValue(_StubPrompt()),
          windowLinkProvider.overrideWithValue(const NoWindowLink()),
          watchLinkProvider.overrideWithValue(const NoWatchLink()),
          sessionStoreProvider.overrideWithValue(
            SessionStore(
              directory: root,
              debounce: const Duration(milliseconds: 10),
            ),
          ),
        ],
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    final container = containerOf(tester);
    if (open.isNotEmpty) {
      container.read(openSetProvider.notifier).openPaths(
        <String>[for (final name in open) at(name)],
      );
      await tester.pumpAndSettle();
    }
    return container;
  }

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Finder inSwitcher(Finder matching) =>
      find.descendant(of: find.byType(QuickSwitcher), matching: matching);

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(inSwitcher(find.byType(TextField)), query);
    await tester.pumpAndSettle();
  }

  group('the switcher', () {
    testWidgets('Ctrl+P is no longer a "not wired up" snackbar', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSwitcher(tester);

      expect(find.byType(QuickSwitcher), findsOneWidget);
    });

    testWidgets('opens listing everything, most recently used first', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSwitcher(tester);

      expect(inSwitcher(find.text('ARCHITECTURE.md')), findsOneWidget);
      expect(inSwitcher(find.text('README.md')), findsOneWidget);
    });

    testWidgets('a query narrows it, best match first', (tester) async {
      await pumpApp(tester, open: <String>['random-numbers.md', 'README.md']);
      await openSwitcher(tester);

      await type(tester, 'rdm');

      // `rdm` *is* a subsequence of both — r-a-n-**d**-o-**m** — so this is a
      // ranking question, not a filtering one, which is the whole reason the
      // scorer is a dynamic program and not a contains() call.
      expect(inSwitcher(find.text('README.md')), findsOneWidget);
      expect(inSwitcher(find.text('random-numbers.md')), findsOneWidget);
      expect(
        tester.getTopLeft(inSwitcher(find.text('README.md'))).dy,
        lessThan(
          tester.getTopLeft(inSwitcher(find.text('random-numbers.md'))).dy,
        ),
        reason: 'the file you meant has to be the one you land on',
      );
    });

    testWidgets('Enter opens the selected file', (tester) async {
      final container = await pumpApp(tester);
      await openSwitcher(tester);
      await type(tester, 'readme');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(QuickSwitcher), findsNothing);
      expect(container.read(openSetProvider).active?.file.name, 'README.md');
    });

    testWidgets('arrows move the selection before Enter takes it', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openSwitcher(tester);
      // No query, so the list is MRU. `openPaths` activates the *first* path
      // it was given, so README.md is row 0 and one arrow down is
      // ARCHITECTURE.md.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).active?.file.name,
        'ARCHITECTURE.md',
      );
    });

    testWidgets('a click opens it too', (tester) async {
      final container = await pumpApp(tester);
      await openSwitcher(tester);
      await type(tester, 'arch');

      await tester.tap(inSwitcher(find.text('ARCHITECTURE.md')));
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).active?.file.name,
        'ARCHITECTURE.md',
      );
    });

    testWidgets('says so when nothing matches, rather than showing nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSwitcher(tester);

      await type(tester, 'zzzzzz');

      expect(inSwitcher(find.text('Nothing matches')), findsOneWidget);
    });
  });

  group('the recent list', () {
    testWidgets('survives closing the file, which is the whole point', (
      tester,
    ) async {
      // Before M3 the list was rebuilt from the open set on every save, so
      // this was the one thing it could not do.
      final container = await pumpApp(tester);
      final identity = container.read(openSetProvider).entries.first.identity;

      container.read(openSetProvider.notifier).close(identity);
      await tester.pumpAndSettle();

      expect(
        container.read(recentFilesProvider),
        contains(at('README.md')),
        reason: 'a recent list that only holds open files is a tab strip',
      );
    });

    testWidgets('offers closed files, badged as not open', (tester) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).closeAll();
      await tester.pumpAndSettle();

      await openSwitcher(tester);

      expect(inSwitcher(find.text('README.md')), findsOneWidget);
      expect(inSwitcher(find.text('recent')), findsWidgets);
    });

    testWidgets('and choosing one opens it again', (tester) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).closeAll();
      await tester.pumpAndSettle();
      expect(container.read(openSetProvider).entries, isEmpty);

      await openSwitcher(tester);
      await type(tester, 'readme');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).active?.file.name, 'README.md');
    });

    testWidgets('the empty state offers it, with the two Open buttons', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).closeAll();
      await tester.pumpAndSettle();

      // doc 06's first-run surface: "drop hint + Open buttons + recent list".
      expect(find.textContaining('Drop', findRichText: true), findsWidgets);
      expect(
        find.widgetWithText(FilledButton, 'Open Folder…'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'README.md'), findsOneWidget);
    });

    testWidgets('File → Open Recent lists it instead of saying "none"', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).closeAll();
      await tester.pumpAndSettle();

      // `MenuAcceleratorLabel` strips the `&` from the translated title, so
      // the rendered text is "File" (docs/06, accelerators).
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Recent').first);
      await tester.pumpAndSettle();

      expect(find.text('No recent documents'), findsNothing);
      expect(
        find.widgetWithText(MenuItemButton, 'ARCHITECTURE.md'),
        findsOneWidget,
      );
    });

    testWidgets('and it round-trips through session.json', (tester) async {
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).closeAll();
      ref(container).flush();

      final reloaded = SessionStore(directory: root).load().state;

      expect(
        reloaded.recent,
        contains(at('README.md')),
        reason: 'the field has been written since M1 and read by nobody',
      );
    });
  });
}

/// The session link, for a test that wants to force a write.
SessionLink ref(ProviderContainer container) =>
    container.read(sessionLinkProvider);
