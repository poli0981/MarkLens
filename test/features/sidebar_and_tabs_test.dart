/// `docs/06_UI_UX.md`: the sidebar's two presentations and its badges, and the
/// tab strip's pinning, dot and middle-click close.
///
/// Neither widget imports the other; both read the open set through
/// `app/providers.dart`, and this file checks that they agree about it
/// (`docs/02_ARCHITECTURE.md`).
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/files/file_service.dart';
import 'package:marklens/features/sidebar/sidebar_tree.dart';
import 'package:marklens/features/tabs/tab_strip.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory root;
  late ProviderContainer container;

  String at(String relative) =>
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}';

  void writeFile(String relative) {
    final file = File(at(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('# Doc');
  }

  OpenSetController controller() => container.read(openSetProvider.notifier);

  String identityOf(String relative) =>
      const FileService().describe(at(relative))!.identity;

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_ui_');
    container = ProviderContainer(
      overrides: [configDirectoryProvider.overrideWithValue(root)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(900, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the sidebar row list', () {
    test('flat when files were opened one at a time', () {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);

      final rows = SidebarTree.buildRows(container.read(openSetProvider));
      expect(rows.map((r) => r.label), <String>['a.md', 'b.md']);
      expect(rows.every((r) => r.entry != null), isTrue);
    });

    test('grouped under a header when a folder was opened', () {
      writeFile('docs/10.md');
      writeFile('docs/2.md');
      controller().openFolder(root.path);

      final rows = SidebarTree.buildRows(container.read(openSetProvider));
      expect(rows.first.entry, isNull, reason: 'the root becomes a header');
      expect(
        rows.skip(1).map((r) => r.label),
        <String>['2.md', '10.md'],
        reason: 'natural sort inside a folder (docs/07)',
      );
    });

    test('a file below the root shows its folder', () {
      writeFile('guide/intro.md');
      controller().openFolder(root.path);

      final rows = SidebarTree.buildRows(container.read(openSetProvider));
      expect(rows.last.detail, 'guide');
    });

    test('roots and loose files are separated', () {
      writeFile('inside/a.md');
      writeFile('loose.md');
      controller()
        ..openFolder(at('inside'))
        ..openPaths(<String>[at('loose.md')]);

      final rows = SidebarTree.buildRows(container.read(openSetProvider));
      final labels = rows.map((r) => r.label).toList();
      expect(labels, contains('a.md'));
      expect(labels, contains('loose.md'));
      expect(
        rows.where((r) => r.entry == null).length,
        2,
        reason: 'one header for the root, one divider before the loose files',
      );
    });

    test('a file is claimed by exactly one root', () {
      writeFile('inside/a.md');
      controller()
        ..openFolder(root.path)
        ..openFolder(at('inside'));

      final rows = SidebarTree.buildRows(container.read(openSetProvider));
      expect(
        rows.where((r) => r.entry != null).length,
        1,
        reason: 'a nested root must not list the same document twice',
      );
    });
  });

  group('the sidebar widget', () {
    testWidgets('says so when nothing is open', (tester) async {
      await pump(tester, const SidebarTree());
      expect(find.text('No documents open.'), findsOneWidget);
    });

    testWidgets('clicking a row activates it', (tester) async {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      await pump(tester, const SidebarTree());

      await tester.tap(find.text('b.md'));
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).active!.file.name, 'b.md');
    });

    testWidgets('a missing file is badged, not removed', (tester) async {
      writeFile('a.md');
      controller().openPaths(<String>[at('a.md')]);
      File(at('a.md')).deleteSync();
      controller().refreshAll();

      await pump(tester, const SidebarTree());

      expect(find.text('a.md'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });
  });

  group('the tab strip', () {
    testWidgets('shows nothing when nothing is open', (tester) async {
      await pump(tester, const TabStrip());
      expect(find.byKey(const Key('tab-strip')), findsNothing);
    });

    testWidgets('pinned tabs come first without reordering the rest', (
      tester,
    ) async {
      writeFile('a.md');
      writeFile('b.md');
      writeFile('c.md');
      controller()
        ..openPaths(<String>[at('a.md'), at('b.md'), at('c.md')])
        ..togglePin(identityOf('c.md'));

      await pump(tester, const TabStrip());

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('tab-strip')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(labels, <String?>['c.md', 'a.md', 'b.md']);
    });

    testWidgets('the close button closes the tab', (tester) async {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      await pump(tester, const TabStrip());

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, hasLength(1));
    });

    testWidgets('middle-click closes too', (tester) async {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      await pump(tester, const TabStrip());

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('b.md')),
        buttons: kMiddleMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).entries.map((e) => e.file.name),
        <String>['a.md'],
      );
    });

    testWidgets('a stale tab carries the dot', (tester) async {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      File(at('b.md')).writeAsStringSync('# Changed, and longer than before');
      controller().refreshAll();

      await pump(tester, const TabStrip());

      expect(
        find.byIcon(Icons.circle),
        findsOneWidget,
        reason: 'the dot marks the background tab that changed on disk',
      );
    });
  });

  group('the two views agree', () {
    testWidgets('activating in the sidebar moves the strip', (tester) async {
      writeFile('a.md');
      writeFile('b.md');
      controller().openPaths(<String>[at('a.md'), at('b.md')]);

      await pump(
        tester,
        const Column(
          children: <Widget>[
            TabStrip(),
            Expanded(child: SidebarTree()),
          ],
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('sidebar')),
          matching: find.text('b.md'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(openSetProvider).activeIdentity,
        identityOf('b.md'),
      );
    });
  });
}
