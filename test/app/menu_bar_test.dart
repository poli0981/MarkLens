import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Spike S4's objective half: the menu bar is reachable, traversable and
/// dismissable from the keyboard alone (`docs/06_UI_UX.md`), and every label
/// comes from ARB (CLAUDE.md rule 4).
///
/// The subjective half — whether it *feels* right — is the maintainer's call.
void main() {
  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    // The shell restores a session on its first frame, so it needs somewhere
    // to restore from. A temp directory keeps that real without touching the
    // developer's own config.
    final config = Directory.systemTemp.createTempSync('marklens_menu_');
    addTearDown(() {
      if (config.existsSync()) {
        config.deleteSync(recursive: true);
      }
    });
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        // Cold start records a session, and its one-second debounce would
        // still be pending when the test ends. The default is asserted in
        // session_store_test; here it only has to be short.
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
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Let the cold-start save land rather than leaving its timer pending.
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// Presses and releases Alt with nothing in between.
  Future<void> tapAlt(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  /// The File menu is open when its first item is on screen.
  bool fileMenuIsOpen(WidgetTester tester, AppLocalizations l10n) =>
      find.text(l10n.menuOpenFiles).evaluate().isNotEmpty;

  group('keyboard reachability', () {
    testWidgets('Alt opens the File menu', (tester) async {
      // docs/06 asked for Alt to *focus* the bar. Flutter's MenuBar excludes
      // itself from focus while closed, so opening is the closest achievable
      // behaviour — see docs/spike-results/S4-menubar.md.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpShell(tester);
      expect(fileMenuIsOpen(tester, l10n), isFalse);

      await tapAlt(tester);
      expect(
        fileMenuIsOpen(tester, l10n),
        isTrue,
        reason: 'Alt did not open the File menu',
      );
    });

    testWidgets('Alt again closes it, so it is not a one-way trip', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpShell(tester);

      await tapAlt(tester);
      expect(fileMenuIsOpen(tester, l10n), isTrue);

      await tapAlt(tester);
      expect(fileMenuIsOpen(tester, l10n), isFalse);
    });

    testWidgets('Alt+V opens the View menu directly', (tester) async {
      // The accelerator markers in the translated titles (&View) are what make
      // this work, and what underlines the letter while Alt is held.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpShell(tester);

      // Flutter registers accelerators as CharacterActivator(alt: true), which
      // matches on the produced character rather than the logical key — so the
      // event has to carry one. And the labels only register their accelerator
      // once Alt is down, hence the pump in between.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV, character: 'v');
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(find.text(l10n.menuToggleSidebar), findsOneWidget);
      expect(fileMenuIsOpen(tester, l10n), isFalse);
    });

    testWidgets('Alt as part of a combination is left alone', (tester) async {
      // Alt+F4 and friends must reach the platform untouched. The moment
      // another key arrives, the press stops being a bare Alt.
      await pumpShell(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      expect(
        fileMenuIsOpen(tester, l10n),
        isFalse,
        reason: 'Alt+F4 was treated as a bare Alt',
      );
    });

    testWidgets('arrows traverse the bar and Esc closes the menu', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await pumpShell(tester);

      await tapAlt(tester);
      expect(find.text(l10n.menuOpenFiles), findsOneWidget);

      // Right moves to the next top-level menu, whose items replace them.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.menuToggleSidebar),
        findsOneWidget,
        reason: 'arrow-right did not move on to the View menu',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.menuToggleSidebar),
        findsNothing,
        reason: 'Esc did not close the menu',
      );
    });
  });

  group('the View menu is live', () {
    testWidgets('its shortcuts change the chrome', (tester) async {
      final container = await pumpShell(tester);
      expect(container.read(chromeProvider).sidebarVisible, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(container.read(chromeProvider).sidebarVisible, isFalse);
    });

    testWidgets('zoom clamps at both ends', (tester) async {
      final container = await pumpShell(tester);
      final controller = container.read(chromeProvider.notifier);

      for (var i = 0; i < 50; i++) {
        controller.zoomBy(1);
      }
      expect(container.read(chromeProvider).zoom, ChromeController.maxZoom);

      for (var i = 0; i < 100; i++) {
        controller.zoomBy(-1);
      }
      expect(container.read(chromeProvider).zoom, ChromeController.minZoom);

      controller.zoomBy(0);
      expect(container.read(chromeProvider).zoom, 1.0);
      // Chrome changes schedule a session write; let it land.
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('full screen hides the menu bar', (tester) async {
      final container = await pumpShell(tester);
      expect(find.byType(MenuBar), findsOneWidget);

      container.read(chromeProvider.notifier).toggleFullScreen();
      await tester.pumpAndSettle();

      expect(find.byType(MenuBar), findsNothing);
    });
  });

  group('accelerators', () {
    // Two menus answering the same Alt+key is a bug you only notice by
    // accident, and it is per-locale: the letters differ in every language.
    for (final code in <String>['en', 'vi', 'ja']) {
      test('are present and distinct in $code', () async {
        final l10n = await AppLocalizations.delegate.load(Locale(code));
        final letters = <String, String>{};
        for (final entry in <String, String>{
          'File': l10n.menuFile,
          'View': l10n.menuView,
          'Help': l10n.menuHelp,
        }.entries) {
          final letter = _accelerator(entry.value);
          expect(
            letter,
            isNotNull,
            reason: '${entry.key} in $code has no & marker: ${entry.value}',
          );
          expect(
            letters,
            isNot(contains(letter)),
            reason:
                '$code: ${entry.key} and ${letters[letter]} both answer '
                'Alt+$letter',
          );
          letters[letter!] = entry.key;
        }
      });
    }
  });

  group('every label comes from ARB', () {
    testWidgets('the bar is Vietnamese in the vi locale', (tester) async {
      final vi = await AppLocalizations.delegate.load(const Locale('vi'));
      await pumpShell(tester, locale: const Locale('vi'));

      // The accelerator marker is stripped before display, so the visible
      // label is 'Tệp', not '&Tệp'.
      for (final label in <String>[vi.menuFile, vi.menuView, vi.menuHelp]) {
        expect(
          find.text(MenuAcceleratorLabel.stripAcceleratorMarkers(label)),
          findsOneWidget,
        );
      }
      // The English source strings must not leak through.
      expect(find.text('File'), findsNothing);
      expect(find.text('View'), findsNothing);
      expect(find.text('Help'), findsNothing);
    });

    testWidgets('and Japanese in the ja locale, items included', (
      tester,
    ) async {
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      await pumpShell(tester, locale: const Locale('ja'));

      await tapAlt(tester);

      expect(find.text(ja.menuOpenFiles), findsOneWidget);
      expect(find.text(ja.menuReload), findsOneWidget);
      expect(find.text('Reload'), findsNothing);
    });
  });
}

/// The accelerator letter marked with `&` in [label], lowercased.
String? _accelerator(String label) {
  var index = -1;
  final stripped = MenuAcceleratorLabel.stripAcceleratorMarkers(
    label,
    setIndex: (i) => index = i,
  );
  return index < 0 ? null : stripped[index].toLowerCase();
}
