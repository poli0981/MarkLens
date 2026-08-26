/// `docs/03_DATA_FLOW.md` activation: File → Open reaches the file service,
/// the cache and the pipeline, in that order, and what comes back is what the
/// reader draws.
///
/// The file dialog is a platform plugin, so it sits behind `FilePickerPrompt`
/// and this test hands over a stub. Everything below that seam — describing the
/// file, reading its bytes, the cache lookup, the parse — is the real thing
/// against a real file on disk.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/documents.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';

/// Returns whatever it was told to, without touching a platform dialog.
class _StubPrompt implements FilePickerPrompt {
  _StubPrompt(this.paths);

  List<String> paths;
  int calls = 0;

  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async {
    calls++;
    return paths;
  }
}

void main() {
  late Directory root;
  late File document;
  late _StubPrompt prompt;

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_open_');
    document = File('${root.path}${Platform.pathSeparator}README.md')
      ..writeAsStringSync('---\ntitle: Opened\n---\n\n# Hello from disk\n');
    prompt = _StubPrompt(<String>[document.path]);
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

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1200, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // The list type is inferred: flutter_riverpod does not export the
        // `Override` class, so it cannot be named here.
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          filePickerPromptProvider.overrideWithValue(prompt),
        ],
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    return containerOf(tester);
  }

  Future<void> openFiles(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('opening a document', () {
    testWidgets('the empty state gives way to the document', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('Drop', findRichText: true), findsWidgets);

      await openFiles(tester);

      expect(prompt.calls, 1);
      expect(
        find.textContaining('Hello from disk', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('the front matter reaches the panel, not the document', (
      tester,
    ) async {
      await pumpApp(tester);
      await openFiles(tester);

      expect(find.text('Front matter'), findsOneWidget);
      expect(
        find.textContaining('title: Opened', findRichText: true),
        findsNothing,
        reason: 'the block must never reach the renderer (docs/04 stage 2)',
      );
    });

    testWidgets('a cancelled dialog changes nothing', (tester) async {
      final container = await pumpApp(tester);
      prompt.paths = <String>[];

      await openFiles(tester);

      expect(container.read(activeDocumentProvider).hasDocument, isFalse);
    });

    testWidgets('a path that is not a file reports rather than throws', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      prompt.paths = <String>['${root.path}${Platform.pathSeparator}gone.md'];

      await openFiles(tester);

      final active = container.read(activeDocumentProvider);
      expect(active.hasDocument, isFalse);
      expect(active.failedPath, isNotNull);
      expect(
        find.textContaining('could not be opened'),
        findsOneWidget,
        reason: 'the user chose it, so the user hears about it',
      );
    });
  });

  group('the cache is on the activation path', () {
    testWidgets('a second open of an unchanged file does not re-parse', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openFiles(tester);

      final first = container.read(activeDocumentProvider).doc;
      expect(container.read(docCacheProvider).length, 1);

      container.read(activeDocumentProvider.notifier)
        ..close()
        ..open(document.path);

      expect(
        identical(container.read(activeDocumentProvider).doc, first),
        isTrue,
        reason:
            'the same bytes with the same mtime is the same document; parsing '
            'it twice is the work the cache exists to avoid',
      );
    });

    testWidgets('reload ignores the cache and picks up the new bytes', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openFiles(tester);

      document.writeAsStringSync('# Changed on disk\n');
      container.read(activeDocumentProvider.notifier).reload();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Changed on disk', findRichText: true),
        findsOneWidget,
      );
      expect(
        container.read(docCacheProvider).length,
        1,
        reason: 'the stale entry was invalidated, not left beside the new one',
      );
    });
  });

  group('File → Copy entire document', () {
    testWidgets('copies the raw file, front matter included', (tester) async {
      final container = await pumpApp(tester);
      await openFiles(tester);

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

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        copied,
        contains('title: Opened'),
        reason:
            'sanitizedSource has the front matter stripped, so copying it '
            'would quietly drop what the user wrote (docs/06)',
      );
      expect(copied, container.read(activeDocumentProvider).doc!.rawSource);
    });
  });
}
