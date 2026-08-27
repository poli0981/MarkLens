/// The layout and copy of the shell chrome — the half of `docs/06_UI_UX.md`
/// that behaviour tests are blind to.
///
/// Every assertion here corresponds to a defect the maintainer found by
/// *looking* at the running app, after 716 passing tests
/// (`docs/15_SPIKES_ROADMAP.md`, "What the first visual pass found"). They are
/// written as geometry and as copy, because that is what broke.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  const window = Size(1200, 800);

  late Directory config;

  String at(String name) => '${config.path}${Platform.pathSeparator}$name';

  String write(String name, String contents) {
    File(at(name)).writeAsStringSync(contents);
    return at(name);
  }

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_layout_');
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        // Real watchers on a temp directory would race real timers
        // against the test binding's clock, the same reason
        // NoWindowLink exists.
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
      ..physicalSize = window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
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

  Future<AppLocalizations> strings([Locale locale = const Locale('en')]) =>
      AppLocalizations.delegate.load(locale);

  group('the menu bar sits at the left', () {
    testWidgets('flush against the window edge, spanning its width', (
      tester,
    ) async {
      await pumpShell(tester);

      final bar = find.byType(MenuBar);
      expect(
        tester.getTopLeft(bar).dx,
        0,
        reason:
            'the shell Column defaulted to centring, and MenuBar is the only '
            'child that shrink-wraps — so the bar floated mid-window while '
            'the doc 06 diagram puts it at the left',
      );
      expect(tester.getSize(bar).width, window.width);
    });

    testWidgets('and packs its items left inside it', (tester) async {
      await pumpShell(tester);
      final l10n = await strings();

      expect(
        tester.getTopLeft(find.text(l10n.menuFile.replaceAll('&', ''))).dx,
        lessThan(window.width / 4),
        reason: 'a stretched bar must not centre its own contents instead',
      );
    });
  });

  group('the sidebar is the width the session remembered', () {
    testWidgets('not a hardcoded one', (tester) async {
      final container = await pumpShell(tester);
      container
          .read(chromeProvider.notifier)
          .restore(sidebarWidth: 320, outlineVisible: true);
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(const Key('sidebar'))).width,
        320,
        reason:
            'the shell hardcoded 240 while the session stored, clamped and '
            'restored a width nobody ever read',
      );
    });
  });

  group('the status bar says what doc 06 says it says', () {
    testWidgets('nothing open, so it says so', (tester) async {
      await pumpShell(tester);
      final l10n = await strings();

      expect(find.byKey(const Key('status-bar')), findsOneWidget);
      expect(find.text(l10n.statusBarNoDocument), findsOneWidget);
    });

    testWidgets('path, position and word count', (tester) async {
      final path = write('notes.md', '# Title\n\nHello world.\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      final bar = find.byKey(const Key('status-bar'));

      expect(
        find.descendant(of: bar, matching: find.text(path)),
        findsOneWidget,
        reason: 'the display path, not the case-folded identity (doc 07)',
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.textContaining(l10n.statusBarWordCount(3)),
        ),
        findsOneWidget,
        reason: 'Title, Hello and world. — the hash is punctuation',
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.textContaining(l10n.statusBarPosition(0)),
        ),
        findsOneWidget,
        reason: 'a document opens at the top',
      );
    });

    testWidgets('and counts notices when there are any', (tester) async {
      final path = write('broken.md', '---\nnot a pair\n---\n\n# Hi\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.textContaining(l10n.statusBarNotices(1)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no notice field when the document is clean', (tester) async {
      final path = write('clean.md', '# Clean\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      expect(
        find.descendant(
          of: find.byKey(const Key('status-bar')),
          matching: find.textContaining(l10n.statusBarNotices(0)),
        ),
        findsNothing,
        reason: 'zero notices is noise; the field is absent when it is empty',
      );
    });
  });

  group('the chrome speaks the active language', () {
    testWidgets('the outline panel is not hardcoded English', (tester) async {
      await pumpShell(tester, locale: const Locale('vi'));
      final vi = await strings(const Locale('vi'));

      expect(
        find.text(vi.outlineEmpty),
        findsOneWidget,
        reason: 'nothing is open, so the panel says the document has none',
      );
      expect(
        find.text('Outline'),
        findsNothing,
        reason: 'the placeholder shipped a raw English literal (rule 4)',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('outline'))).label,
        contains(vi.outlinePanelTitle),
        reason:
            'the panel name is a screen-reader label rather than 24 px of a '
            '200 px panel (doc 06, Accessibility)',
      );
    });

    testWidgets('and neither is the status bar', (tester) async {
      await pumpShell(tester, locale: const Locale('ja'));
      final ja = await strings(const Locale('ja'));

      expect(find.text(ja.statusBarNoDocument), findsOneWidget);
    });
  });
}
