/// The File menu does what it says, through the same actions the shortcuts
/// use (`docs/06_UI_UX.md`, "Menu map").
///
/// Every File item used to be a `todo()` snackbar while the identical `Ctrl+O`,
/// `Ctrl+R`, `Ctrl+Shift+C` and `Ctrl+W` were fully bound — the menu advertised
/// behaviour it did not have. Routing both through one `Actions` map is what
/// makes that unrepresentable, and this file is what holds it.
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
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory config;

  String at(String name) => '${config.path}${Platform.pathSeparator}$name';

  String write(String name, String contents) {
    File(at(name)).writeAsStringSync(contents);
    return at(name);
  }

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_menu_actions_');
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// Opens the File menu the way `Alt` does (spike S4).
  Future<void> openFileMenu(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
  }

  Future<void> chooseFile(WidgetTester tester, String label) async {
    await openFileMenu(tester);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<AppLocalizations> strings() =>
      AppLocalizations.delegate.load(const Locale('en'));

  /// Restricts a finder to the reading surface.
  Finder inReader(Finder matching) =>
      find.descendant(of: find.byType(ReaderView), matching: matching);

  group('the File menu reaches its actions', () {
    testWidgets('Close Tab closes the active document', (tester) async {
      final a = write('a.md', '# A\n');
      final b = write('b.md', '# B\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[a, b]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      await chooseFile(tester, l10n.menuCloseTab);

      expect(
        container.read(openSetProvider).entries,
        hasLength(1),
        reason: 'the menu item must do what Ctrl+W does, not describe it',
      );
    });

    testWidgets('Close All empties the open set', (tester) async {
      final a = write('a.md', '# A\n');
      final b = write('b.md', '# B\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[a, b]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      await chooseFile(tester, l10n.menuCloseAll);

      expect(container.read(openSetProvider).entries, isEmpty);
    });

    testWidgets('Copy entire document reaches the clipboard', (tester) async {
      const source = '---\ntitle: Kept\n---\n\n# Body\n';
      final path = write('doc.md', source);
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final l10n = await strings();
      await chooseFile(tester, l10n.menuCopyDocument);

      expect(
        copied,
        source,
        reason: 'rawSource, front matter included (docs/06)',
      );
    });

    testWidgets('Reload re-reads the document from disk', (tester) async {
      final path = write('doc.md', '# Before\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      expect(inReader(find.text('Before')), findsOneWidget);

      File(path).writeAsStringSync('# After\n');
      final l10n = await strings();
      await chooseFile(tester, l10n.menuReload);

      // Scoped to the reader: the outline panel shows heading text too, so an
      // unscoped matcher would find the same heading twice.
      expect(inReader(find.text('After')), findsOneWidget);
      expect(inReader(find.text('Before')), findsNothing);
    });
  });

  group('nothing in the File menu claims to be unfinished', () {
    testWidgets('when it is not', (tester) async {
      final path = write('doc.md', '# A\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      final l10n = await strings();
      for (final item in <String>[
        l10n.menuReload,
        l10n.menuCloseTab,
        l10n.menuCloseAll,
      ]) {
        await chooseFile(tester, item);
        expect(
          find.text(l10n.menuNotImplemented(item)),
          findsNothing,
          reason: '$item is implemented and the menu must not say otherwise',
        );
        container.read(openSetProvider.notifier).openPaths(<String>[path]);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('and still says so for the ones that are', (tester) async {
      await pumpShell(tester);
      final l10n = await strings();

      // Settings is genuinely M3. An honest placeholder is not the defect;
      // claiming a working item is unfinished was.
      await chooseFile(tester, l10n.menuSettings);
      expect(find.text(l10n.menuNotImplemented(l10n.menuSettings)), findsOne);
    });
  });
}
