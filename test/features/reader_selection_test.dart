import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';

/// Selection and copy quality — a release gate
/// (`docs/15_SPIKES_ROADMAP.md` S2, `docs/12_TESTING.md`).
///
/// Every assertion checks the clipboard is **non-empty before** inspecting it.
/// A selection test that silently selects nothing passes for the wrong reason,
/// which is exactly how the S1 perf harness once reported 1078 fps on a list
/// that never scrolled.
void main() {
  const mixedBlocks = '''
# Chương một

Một đoạn văn có dấu tiếng Việt: chào bạn, thế giới.

日本語の段落です。テキストを選択できますか。

```dart
void main() {
  print('hello');
}
```

| Cột A | Cột B |
|---|---|
| ô một | ô hai |

Đoạn cuối cùng.
''';

  late List<String> clipboard;

  setUp(() {
    clipboard = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>;
            clipboard.add(args['text'] as String? ?? '');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('selection across block types', () {
    testWidgets('copies every block type cleanly', (tester) async {
      await _pump(tester, mixedBlocks);
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty, reason: 'nothing was selected at all');
      expect(text, contains('Chương một'), reason: 'heading missing');
      expect(text, contains('chào bạn'), reason: 'paragraph missing');
      expect(text, contains('日本語'), reason: 'Japanese paragraph missing');
      expect(text, contains("print('hello')"), reason: 'code block missing');
      expect(text, contains('ô hai'), reason: 'table cell missing');
      expect(text, contains('Đoạn cuối cùng'), reason: 'last block missing');
    });

    testWidgets('Vietnamese diacritics survive the round trip', (tester) async {
      await _pump(tester, mixedBlocks);
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty);
      // Not 'Chuong mot' — the marks must come back as written.
      expect(text, contains('Chương một'));
      expect(text, isNot(contains('Chuong mot')));
      expect(text, contains('ô một'));
    });

    testWidgets('code block keeps its newlines and indentation', (
      tester,
    ) async {
      await _pump(tester, mixedBlocks);
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty);
      expect(text, contains('void main() {'));
      expect(
        text,
        contains("  print('hello');"),
        reason: 'code block indentation was lost in the clipboard text',
      );
    });
  });

  group('long-passage selection', () {
    String longDocument(int paragraphs) {
      final buffer = StringBuffer();
      for (var i = 1; i <= paragraphs; i++) {
        buffer
          ..writeln('Paragraph $i, marker M$i.')
          ..writeln();
      }
      return buffer.toString();
    }

    testWidgets('dragging past the edge auto-scrolls and keeps extending', (
      tester,
    ) async {
      // The behaviour that makes the lazy list acceptable: a drag reaches
      // blocks that did not exist when the mouse went down, with no gaps.
      await _pump(
        tester,
        longDocument(120),
        size: const Size(800, 600),
      );

      final builtAtStart = find.byType(RichText).evaluate().length;

      final gesture = await tester.startGesture(
        const Offset(60, 40),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(const Offset(400, 590));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await gesture.moveTo(const Offset(400, 640));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final text = clipboard.isEmpty ? '' : clipboard.last;
      expect(text, isNotEmpty, reason: 'the drag selected nothing');

      final reached = <int>[
        for (var i = 1; i <= 120; i++)
          if (text.contains('marker M$i.')) i,
      ];
      expect(reached, isNotEmpty, reason: 'no paragraph was fully selected');
      expect(
        reached.last,
        greaterThan(builtAtStart),
        reason:
            'the selection stopped at paragraph ${reached.last} while '
            '$builtAtStart blocks were already built, so auto-scroll never '
            'extended it into blocks built during the drag',
      );
      expect(
        reached.last - reached.first + 1,
        reached.length,
        reason: 'the selection has holes: $reached',
      );
    });

    testWidgets('Ctrl+A reaches only what is rendered — by design', (
      tester,
    ) async {
      // Documents the limitation docs/06 was amended for. "Copy entire
      // document" exists precisely because this cannot cover the whole file:
      // building every block to make it possible costs 527 ms at 100 KB and
      // kills the app at 1 MB (docs/spike-results/S2-selection.md).
      await _pump(tester, longDocument(300), size: const Size(800, 600));
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty, reason: 'nothing was selected at all');
      expect(text, contains('marker M1.'));
      expect(
        text,
        isNot(contains('marker M300.')),
        reason:
            'if this ever passes, laziness stopped costing us whole-document '
            'selection and docs/06 is worth revisiting',
      );
    });
  });
}

// The whole model comes from the pipeline rather than being hand-assembled,
// so this gate exercises the same blocks the reader will actually get. Note
// utf8.encode, not codeUnits: the pipeline takes bytes, and code units are
// UTF-16 — identical only while the fixture stays ASCII.
DocModel _doc(String source) => const MarkdownPipeline().parse(
  path: 'test.md',
  bytes: utf8.encode(source),
  isMdx: false,
);

Future<void> _pump(
  WidgetTester tester,
  String source, {
  Size size = const Size(1000, 4000),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionArea(
          child: Builder(
            builder: (context) => const FlutterMarkdownPlusRenderer().build(
              context,
              _doc(source),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Selects with Ctrl+A and copies with Ctrl+C, returning whatever reached the
/// mocked clipboard.
Future<String> _selectAllAndCopy(
  WidgetTester tester,
  List<String> clipboard,
) async {
  // The region has to be focused before it answers keyboard shortcuts, and a
  // click is what a user would do.
  final gesture = await tester.startGesture(
    tester.getTopLeft(find.byType(SelectableRegion).first) + const Offset(8, 8),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await tester.pump();

  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();

  return clipboard.isEmpty ? '' : clipboard.last;
}
