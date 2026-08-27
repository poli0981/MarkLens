/// The find bar (`docs/08_SEARCH.md`): counter, cycling, case toggle, Esc.
///
/// `Ctrl+F` has been bound since M1 to a "not wired up yet" snackbar; these are
/// the first tests of it doing anything.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory config;

  String write(String name, String contents) {
    final path = '${config.path}${Platform.pathSeparator}$name';
    File(path).writeAsStringSync(contents);
    return path;
  }

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_find_');
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpShell(
    WidgetTester tester,
    String source,
  ) async {
    final path = write('doc.md', source);
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        watchLinkProvider.overrideWithValue(const NoWatchLink()),
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

    container.read(openSetProvider.notifier).openPaths(<String>[path]);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> pressCtrlF(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('find-bar')),
        matching: find.byType(TextField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  /// Lets the accent pulse a jump raises expire, so no timer outlives the body.
  Future<void> settlePulse(WidgetTester tester) async {
    await tester.pump(BlockScroller.pulseDuration);
    await tester.pumpAndSettle();
  }

  const document =
      '# Alpha heading\n\n'
      'A paragraph about alpha and more alpha.\n\n'
      'Another paragraph mentioning ALPHA once.\n\n'
      'And a final one with nothing of interest.\n';

  group('opening and closing', () {
    testWidgets('Ctrl+F opens the bar with the field focused', (tester) async {
      await pumpShell(tester, document);
      expect(find.byKey(const Key('find-bar')), findsNothing);

      await pressCtrlF(tester);

      expect(find.byKey(const Key('find-bar')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('find-bar')),
                matching: find.byType(TextField),
              ),
            )
            .focusNode
            ?.hasFocus,
        isTrue,
        reason: 'opening a find bar you then have to click is not a find bar',
      );
    });

    testWidgets('Esc closes it', (tester) async {
      final container = await pumpShell(tester, document);
      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('find-bar')), findsNothing);
      expect(
        container.read(readerScrollProvider).highlightedBlocks.value,
        isEmpty,
        reason: 'closing the bar clears the marks it made',
      );
    });
  });

  group('the counter', () {
    testWidgets('reads current out of total', (tester) async {
      await pumpShell(tester, document);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);

      expect(
        find.text(l10n.findMatchCounter(1, 4)),
        findsOneWidget,
        reason: 'heading, two in one paragraph, and ALPHA case-insensitively',
      );
    });

    testWidgets('says so when nothing matches', (tester) async {
      await pumpShell(tester, document);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await pressCtrlF(tester);
      await type(tester, 'nothing like this');

      expect(find.text(l10n.findNoResults), findsOneWidget);
    });

    testWidgets('the arrows are disabled with no matches', (tester) async {
      await pumpShell(tester, document);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await pressCtrlF(tester);
      await type(tester, 'nothing like this');

      final next = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(l10n.findNext),
          matching: find.byType(IconButton),
        ),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('cycling', () {
    testWidgets('Enter advances and wraps at the end', (tester) async {
      final container = await pumpShell(tester, document);
      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);

      expect(container.read(findProvider).current, 0);

      for (var i = 1; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(container.read(findProvider).current, i);
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        container.read(findProvider).current,
        0,
        reason: 'a find bar that stops at the end is one you have to reopen',
      );
      await settlePulse(tester);
    });

    testWidgets('Shift+Enter reverses and wraps at the start', (tester) async {
      final container = await pumpShell(tester, document);
      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(container.read(findProvider).current, 3);
      await settlePulse(tester);
    });
  });

  group('the case toggle', () {
    testWidgets('changes how many matches there are', (tester) async {
      final container = await pumpShell(tester, document);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);
      expect(container.read(findProvider).hits, hasLength(4));

      await tester.tap(find.byTooltip(l10n.findCaseSensitive));
      await tester.pumpAndSettle();
      await settlePulse(tester);

      expect(
        container.read(findProvider).hits,
        hasLength(2),
        reason:
            'only the two lowercase ones survive — the heading is "Alpha" and '
            'the third paragraph says "ALPHA"',
      );
    });
  });

  group('the reader is marked', () {
    testWidgets('every block holding a match is highlighted', (tester) async {
      final container = await pumpShell(tester, document);
      await pressCtrlF(tester);
      await type(tester, 'alpha');
      await settlePulse(tester);

      final marked = container.read(readerScrollProvider).highlightedBlocks;
      expect(
        marked.value,
        hasLength(3),
        reason: 'four matches, but two of them share a paragraph',
      );
    });
  });
}
