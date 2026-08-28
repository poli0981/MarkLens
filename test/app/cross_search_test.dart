/// `docs/08_SEARCH.md`, `Ctrl+Shift+F`: the panel that replaces the sidebar,
/// and the jump a result click makes.
///
/// The service is overridden with one that scans on this isolate. That is not
/// a convenience: `Isolate.run` inside `testWidgets` runs against real time
/// while the binding drives a fake clock, which is the trap real sockets were
/// at M1. The real round trip is covered in `test/core/search_service_test.dart`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/search/search_service.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/search/search_panel.dart';
import 'package:marklens/features/sidebar/sidebar_tree.dart';

/// Scans on this isolate, so a widget test can drive it with a fake clock.
class _SyncSearchService implements SearchService {
  int calls = 0;

  @override
  Future<List<FileHits>> search({
    required List<String> paths,
    required String query,
    bool caseSensitive = false,
  }) async {
    calls++;
    if (query.isEmpty || paths.isEmpty) {
      return const <FileHits>[];
    }
    return searchFiles((
      paths: paths,
      query: query,
      caseSensitive: caseSensitive,
    ));
  }
}

/// Answers only when told to, so a superseded scan can be observed.
class _HeldSearchService implements SearchService {
  final List<Completer<List<FileHits>>> pending = <Completer<List<FileHits>>>[];
  final List<String> queries = <String>[];

  @override
  Future<List<FileHits>> search({
    required List<String> paths,
    required String query,
    bool caseSensitive = false,
  }) {
    queries.add(query);
    final completer = Completer<List<FileHits>>();
    pending.add(completer);
    return completer.future;
  }
}

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;
  late _SyncSearchService service;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_xsearch_');
    service = _SyncSearchService();

    File(at('alpha.md')).writeAsStringSync('''
# Alpha

${'Filler paragraph.\n\n' * 40}
The needle is here.
''');
    File(at('beta.md')).writeAsStringSync('# Beta\n\nAnother needle line.\n');
    File(at('gamma.md')).writeAsStringSync('# Gamma\n\nNothing to find.\n');
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
    SearchService? searchService,
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
          searchServiceProvider.overrideWithValue(searchService ?? service),
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
    container.read(openSetProvider.notifier).openPaths(<String>[
      at('alpha.md'),
      at('beta.md'),
      at('gamma.md'),
    ]);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  /// Restricts a finder to the search panel.
  ///
  /// The tab strip renders every open file's name too, so an unscoped
  /// `findsNothing` on a filename says nothing about the results — the same
  /// collision the outline caused at M2.
  Finder inPanel(Finder matching) =>
      find.descendant(of: find.byType(SearchPanel), matching: matching);

  /// Types [query] and lets the controller's debounce elapse.
  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  group('the panel replaces the sidebar', () {
    testWidgets('Ctrl+Shift+F is no longer a "not wired up" snackbar', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.byType(SidebarTree), findsOneWidget);

      await openPanel(tester);

      expect(find.byType(SearchPanel), findsOneWidget);
      expect(
        find.byType(SidebarTree),
        findsNothing,
        reason: 'doc 06: it replaces the sidebar rather than joining it',
      );
    });

    testWidgets('closing it puts the file list back', (tester) async {
      final container = await pumpApp(tester);
      await openPanel(tester);

      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();

      expect(find.byType(SidebarTree), findsOneWidget);
      expect(
        container.read(crossSearchProvider).query,
        isEmpty,
        reason: 'closing clears, so reopening is not last week’s search',
      );
    });

    testWidgets('Ctrl+B hides the column and brings back files, not search', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openPanel(tester);

      final chrome = container.read(chromeProvider.notifier)..toggleSidebar();
      expect(container.read(chromeProvider).sidebarVisible, isFalse);

      chrome.toggleSidebar();
      await tester.pumpAndSettle();

      expect(container.read(chromeProvider).sidebarPanel, SidebarPanel.files);
    });
  });

  group('results', () {
    testWidgets('are grouped by file, with a line number and context', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPanel(tester);

      await type(tester, 'needle');

      expect(inPanel(find.text('alpha.md')), findsOneWidget);
      expect(inPanel(find.text('beta.md')), findsOneWidget);
      expect(
        inPanel(find.text('gamma.md')),
        findsNothing,
        reason: 'a file with no matches is absent, not empty',
      );
      expect(inPanel(find.text('The needle is here.')), findsOneWidget);
      expect(inPanel(find.text('Another needle line.')), findsOneWidget);
      final line =
          File(at('alpha.md'))
              .readAsLinesSync()
              .indexWhere((l) => l.contains('needle')) +
          1;
      expect(
        inPanel(find.text('$line')),
        findsOneWidget,
        reason: 'the line number is 1-based, as an editor shows it',
      );
    });

    testWidgets('the summary counts matches and files', (tester) async {
      await pumpApp(tester);
      await openPanel(tester);

      await type(tester, 'needle');

      expect(inPanel(find.text('2 matches in 2 files')), findsOneWidget);
    });

    testWidgets('and says so when there are none', (tester) async {
      await pumpApp(tester);
      await openPanel(tester);

      await type(tester, 'unfindable');

      expect(
        inPanel(find.text('No matches in the open files')),
        findsOneWidget,
      );
    });

    testWidgets('clicking one activates its tab and lands on the match', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      // Start somewhere else, so activation is observable.
      container
          .read(openSetProvider.notifier)
          .activate(
            container.read(openSetProvider).entries.last.identity,
          );
      await tester.pumpAndSettle();
      await openPanel(tester);
      await type(tester, 'needle');

      await tester.tap(inPanel(find.text('The needle is here.')));
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).active?.file.name,
        'alpha.md',
      );
      expect(
        container.read(readerScrollProvider).controller.offset,
        greaterThan(0),
        reason: 'the match is 40 paragraphs down; the top is not the answer',
      );
      // reveal() lights a 900 ms pulse; leaving it pending fails the test
      // after the body passes.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('cancellation, from the caller’s end', () {
    testWidgets('one scan per settled query, not one per keystroke', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPanel(tester);

      final field = find.byType(TextField).first;
      for (final partial in <String>['n', 'ne', 'nee', 'need', 'needle']) {
        await tester.enterText(field, partial);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(
        service.calls,
        1,
        reason: 'the debounce is what stops five isolates for one word',
      );
    });

    testWidgets('a superseded scan’s result is thrown away', (tester) async {
      final held = _HeldSearchService();
      final container = await pumpApp(tester, searchService: held);
      await openPanel(tester);

      await type(tester, 'first');
      expect(held.queries, <String>['first']);

      await type(tester, 'second');
      expect(held.queries, <String>['first', 'second']);

      // The first scan finishes last, which is exactly the race the generation
      // counter exists for: Isolate.run cannot be killed, so a stale answer has
      // to be recognised rather than prevented.
      held.pending.first.complete(<FileHits>[
        const FileHits(
          path: 'stale.md',
          hits: <CrossSearchHit>[(line: 0, column: 0, preview: 'stale')],
        ),
      ]);
      await tester.pumpAndSettle();

      expect(container.read(crossSearchProvider).results, isEmpty);
      expect(inPanel(find.text('stale')), findsNothing);

      held.pending.last.complete(const <FileHits>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('clearing the query clears the results with it', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openPanel(tester);
      await type(tester, 'needle');
      expect(container.read(crossSearchProvider).results, isNotEmpty);

      await type(tester, '');

      expect(container.read(crossSearchProvider).results, isEmpty);
      expect(container.read(crossSearchProvider).running, isFalse);
    });
  });
}
