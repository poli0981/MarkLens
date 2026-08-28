/// `docs/03_DATA_FLOW.md`'s four link cases, driven as real taps on real
/// rendered links, against real files on disk.
///
/// `test/core/link_target_test.dart` covers which href is which. What this adds
/// is the half that only exists once a link is wired to something: that an
/// anchor moves the reader, that a relative link opens a tab, that an `http`
/// link reaches the launcher seam and a `javascript:` one never does, and that
/// each failure says so rather than doing nothing.
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
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/reader/reader_view.dart';

class _StubPrompt implements FilePickerPrompt {
  _StubPrompt(this.paths);

  List<String> paths;

  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async => paths;

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;
  late RecordingLauncherLink launcher;
  late _StubPrompt prompt;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_links_');
    launcher = RecordingLauncherLink();
    prompt = _StubPrompt(<String>[at('README.md')]);

    File(at('README.md')).writeAsStringSync('''
# Guide

- [jump](#deeper-down)
- [sibling](OTHER.md)
- [sibling section](OTHER.md#second-heading)
- [gone](MISSING.md)
- [nowhere](#not-a-heading)
- [site](https://example.com/docs)
- [script](javascript:alert%281%29)
- [picture](diagram.png)

${'Filler paragraph.\n\n' * 40}
## Deeper down

The anchor target.
''');

    File(at('OTHER.md')).writeAsStringSync('''
# Other

${'Padding.\n\n' * 40}
## Second heading

Landed.
''');
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
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          filePickerPromptProvider.overrideWithValue(prompt),
          windowLinkProvider.overrideWithValue(const NoWindowLink()),
          watchLinkProvider.overrideWithValue(const NoWatchLink()),
          launcherLinkProvider.overrideWithValue(launcher),
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
      at('README.md'),
    ]);
    await tester.pumpAndSettle();
    return container;
  }

  /// Taps the rendered link whose text is [label].
  ///
  /// Scoped to the reader: the outline panel renders heading text too, and an
  /// unscoped matcher stops meaning what it says.
  Future<void> tapLink(WidgetTester tester, String label) async {
    final link = find.descendant(
      of: find.byType(ReaderView),
      matching: find.textContaining(label, findRichText: true),
    );
    expect(link, findsWidgets, reason: 'no rendered link reading "$label"');

    // A link inside a RichText is a TextSpan with a recognizer, not a widget.
    // Firing the recognizer is what a tap on it does.
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (rich) => rich.text.toPlainText().contains(label),
        );
    var fired = false;
    text.text.visitChildren((span) {
      final recognizer = span is TextSpan ? span.recognizer : null;
      if (recognizer is TapGestureRecognizer &&
          span.toPlainText().contains(label)) {
        recognizer.onTap?.call();
        fired = true;
        return false;
      }
      return true;
    });
    expect(fired, isTrue, reason: '"$label" is not a tappable link');
    await tester.pumpAndSettle();
  }

  String? snackBarText(WidgetTester tester) {
    final snacks = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (snacks.evaluate().isEmpty) {
      return null;
    }
    return tester.widget<Text>(snacks.first).data;
  }

  group('http and https reach the browser, and nothing else does', () {
    testWidgets('an external link is handed over once', (tester) async {
      await pumpApp(tester);

      await tapLink(tester, 'site');

      expect(launcher.opened, hasLength(1));
      expect(launcher.opened.single.toString(), 'https://example.com/docs');
      expect(snackBarText(tester), isNull, reason: 'it worked; say nothing');
    });

    testWidgets('a javascript: link is refused, and never launched', (
      tester,
    ) async {
      await pumpApp(tester);

      await tapLink(tester, 'script');

      expect(
        launcher.opened,
        isEmpty,
        reason: 'docs/10 invariant 2: no shell-out with document-derived data',
      );
      expect(snackBarText(tester), contains('javascript'));
    });

    testWidgets('a link to a non-document is refused too', (tester) async {
      await pumpApp(tester);

      await tapLink(tester, 'picture');

      expect(launcher.opened, isEmpty);
      expect(snackBarText(tester), isNotNull);
    });
  });

  group('anchors', () {
    testWidgets('a #heading moves the reader down the document', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      final scroller = container.read(readerScrollProvider);
      expect(scroller.controller.offset, 0);

      await tapLink(tester, 'jump');

      expect(
        scroller.controller.offset,
        greaterThan(0),
        reason: 'Outline.bySlug finally has a caller',
      );
      expect(snackBarText(tester), isNull);
      // The reveal pulse is a 900 ms timer; leaving it pending fails the test
      // after the body passes.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an anchor with no heading says so', (tester) async {
      await pumpApp(tester);

      await tapLink(tester, 'nowhere');

      expect(snackBarText(tester), contains('not-a-heading'));
    });
  });

  group('other documents', () {
    testWidgets('a relative link opens it as a tab', (tester) async {
      final container = await pumpApp(tester);
      expect(container.read(openSetProvider).entries, hasLength(1));

      await tapLink(tester, 'sibling');

      final set = container.read(openSetProvider);
      expect(set.entries, hasLength(2));
      expect(set.active?.file.name, 'OTHER.md');
      expect(launcher.opened, isEmpty);
    });

    testWidgets('file.md#anchor lands on the heading, not the top', (
      tester,
    ) async {
      final container = await pumpApp(tester);

      await tapLink(tester, 'sibling section');

      expect(container.read(openSetProvider).active?.file.name, 'OTHER.md');
      expect(
        container.read(readerScrollProvider).controller.offset,
        greaterThan(0),
        reason: 'the jump was asked for before the reader had the document',
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a missing target names the file it could not find', (
      tester,
    ) async {
      final container = await pumpApp(tester);

      await tapLink(tester, 'gone');

      expect(snackBarText(tester), contains('MISSING.md'));
      expect(
        container.read(openSetProvider).entries,
        hasLength(1),
        reason: 'nothing was opened',
      );
    });
  });

  group('the pending jump', () {
    testWidgets('is superseded rather than queued', (tester) async {
      final container = await pumpApp(tester);
      final scroller = container.read(readerScrollProvider)
        ..revealWhenAdopted('a', 3)
        ..revealWhenAdopted('b', 9);

      expect(scroller.hasPendingReveal, isTrue);

      // Adopting a document the last jump did not name drops it rather than
      // saving it: a pending jump is good for the next document the reader
      // takes, and one that fired minutes later would be a surprise.
      scroller.adopt(identity: 'a', blockCount: 20);
      await tester.pump();

      expect(scroller.hasPendingReveal, isFalse);
    });
  });
}
