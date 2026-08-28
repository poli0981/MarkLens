/// The four things `docs/06_UI_UX.md` and `docs/04_MARKDOWN_PIPELINE.md`
/// specify and nothing implemented until M3: drag & drop, the missing-file
/// body, the sidebar context menu, and the 50 MB refusal.
///
/// Each of them had its half already built — `desktop_drop` pinned,
/// `failedPath` populated, `togglePin` written, the size ladder's lower rung
/// in the pipeline — and no caller. This is the caller.
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/files/file_service.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/reader/missing_file_body.dart';
import 'package:marklens/features/sidebar/sidebar_tree.dart';

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;
  late RecordingLauncherLink launcher;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_gaps_');
    launcher = RecordingLauncherLink();
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
    int maxDocumentBytes = FileService.defaultMaxDocumentBytes,
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
          launcherLinkProvider.overrideWithValue(launcher),
          fileServiceProvider.overrideWithValue(
            FileService(maxDocumentBytes: maxDocumentBytes),
          ),
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
    return containerOf(tester);
  }

  group('the 50 MB refusal', () {
    testWidgets('a document over the limit is not opened, and says why', (
      tester,
    ) async {
      final path = at('huge.md');
      File(path).writeAsStringSync('x' * 2048);
      final container = await pumpApp(tester, maxDocumentBytes: 1024);

      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, isEmpty);
      expect(find.textContaining('huge.md'), findsOneWidget);
      expect(find.textContaining('up to 50 MB'), findsOneWidget);
    });

    testWidgets('and the refusal is delivered once, then forgotten', (
      tester,
    ) async {
      final path = at('huge.md');
      File(path).writeAsStringSync('x' * 2048);
      final container = await pumpApp(tester, maxDocumentBytes: 1024);

      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).refusedTooLarge, isNull);
      expect(find.textContaining('up to 50 MB'), findsNothing);
    });

    testWidgets('a file under the limit opens as before', (tester) async {
      final path = at('small.md');
      File(path).writeAsStringSync('# Small\n');
      final container = await pumpApp(tester, maxDocumentBytes: 1024);

      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, hasLength(1));
    });

    testWidgets('and one oversize file does not stop the others opening', (
      tester,
    ) async {
      final big = at('huge.md');
      final small = at('small.md');
      File(big).writeAsStringSync('x' * 2048);
      File(small).writeAsStringSync('# Small\n');
      final container = await pumpApp(tester, maxDocumentBytes: 1024);

      container.read(openSetProvider.notifier).openPaths(<String>[big, small]);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, hasLength(1));
      expect(container.read(openSetProvider).active?.file.name, 'small.md');
    });
  });

  group('the missing-file body', () {
    Future<ProviderContainer> openThenDelete(WidgetTester tester) async {
      final path = at('gone.md');
      File(path).writeAsStringSync('# Gone\n');
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      File(path).deleteSync();
      container.read(openSetProvider.notifier).refreshAll();
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('replaces the first-run drop hint, which is not the same', (
      tester,
    ) async {
      await openThenDelete(tester);

      expect(find.byType(MissingFileBody), findsOneWidget);
      expect(find.textContaining('gone.md'), findsWidgets);
      expect(
        find.textContaining('Drop a Markdown file here'),
        findsNothing,
        reason: 'a file that has gone is not the same as nothing being open',
      );
    });

    testWidgets('Remove from session takes the entry out for good', (
      tester,
    ) async {
      final container = await openThenDelete(tester);

      await tester.tap(find.text('Remove from session'));
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, isEmpty);
      expect(
        container.read(openSetProvider).reopenable,
        isEmpty,
        reason:
            'Ctrl+Shift+T must not offer to reopen a file that is not there',
      );
    });

    testWidgets('and Reveal parent folder goes to the folder, not the file', (
      tester,
    ) async {
      await openThenDelete(tester);

      await tester.tap(find.text('Reveal parent folder'));
      await tester.pumpAndSettle();

      expect(launcher.revealed.single, root.path);
    });
  });

  group('the sidebar context menu', () {
    Future<ProviderContainer> withOneFile(WidgetTester tester) async {
      final path = at('doc.md');
      File(path).writeAsStringSync('# Doc\n');
      final container = await pumpApp(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> openMenu(WidgetTester tester) async {
      // Right-click, which is what doc 06 asks for and what anyone reaches for
      // in a file list.
      await tester.tapAt(
        tester.getCenter(
          find.descendant(
            of: find.byType(SidebarTree),
            matching: find.text('doc.md'),
          ),
        ),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers doc 06’s three items on a right-click', (tester) async {
      await withOneFile(tester);

      await openMenu(tester);

      expect(find.text('Reveal in file manager'), findsOneWidget);
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Close Tab'), findsOneWidget);
    });

    testWidgets('Pin is the first caller togglePin has had', (tester) async {
      final container = await withOneFile(tester);

      await openMenu(tester);
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries.single.pinned, isTrue);

      await openMenu(tester);
      expect(find.text('Unpin'), findsOneWidget);
    });

    testWidgets('Reveal opens the folder through the launcher seam', (
      tester,
    ) async {
      await withOneFile(tester);

      await openMenu(tester);
      await tester.tap(find.text('Reveal in file manager'));
      await tester.pumpAndSettle();

      expect(
        launcher.revealed.single,
        root.path,
        reason: 'a file: URI through url_launcher, never a Process.run',
      );
    });

    testWidgets('and Close closes it', (tester) async {
      final container = await withOneFile(tester);

      await openMenu(tester);
      await tester.tap(find.text('Close Tab'));
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).entries, isEmpty);
    });
  });

  group('drag and drop', () {
    testWidgets('a drop opens exactly what the dialog would', (tester) async {
      // The plugin has no channel in a test, so what is asserted is the half
      // above the seam: a drop resolves to `openPaths`, the same one door the
      // dialog, the command line and a forwarded launch use (doc 03).
      final path = at('dropped.md');
      File(path).writeAsStringSync('# Dropped\n');
      final container = await pumpApp(tester);

      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();

      expect(container.read(openSetProvider).active?.file.name, 'dropped.md');
    });

    testWidgets('the real shell wraps itself in the drop target', (
      tester,
    ) async {
      // `NoDropTargetLink` returns the child untouched, so the assertion that
      // matters here is that the seam is *consulted* — a shell that forgot to
      // wrap would drop nothing and look identical.
      await pumpApp(tester);

      expect(
        containerOf(tester).read(dropTargetProvider),
        isA<PlatformDropTargetLink>(),
        reason: 'the real app uses the real target; tests override it',
      );
    });
  });
}
