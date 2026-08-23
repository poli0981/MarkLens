import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/outline.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';

/// S2 — selection and copy quality (`docs/15_SPIKES_ROADMAP.md`).
///
/// Pass criteria: selecting across a heading, a paragraph, a code block and a
/// table cell must yield clean clipboard text; Vietnamese diacritics and
/// Japanese must survive; and the whole document must be selectable
/// (`docs/06_UI_UX.md`).
///
/// Every test here asserts the clipboard is **non-empty before** it inspects
/// the contents. The S1 perf harness reported a confident "1078 fps" measured
/// on a list that never scrolled; a selection probe that silently selects
/// nothing would fail the same way.
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

  // doc 15's S2 gate, run against BOTH layouts. The quality bar has to hold on
  // the layout that actually ships, not only on the one the eager-layout ladder
  // ruled out.
  for (final layout in ReaderLayout.values) {
    group('selection across block types — ${layout.name}', () {
      testWidgets('copies every block type', (tester) async {
        await _pump(tester, mixedBlocks, layout: layout);
        final text = await _selectAllAndCopy(tester, clipboard);

        expect(text, isNotEmpty, reason: 'nothing was selected at all');
        expect(text, contains('Chương một'), reason: 'heading missing');
        expect(text, contains('chào bạn'), reason: 'paragraph missing');
        expect(text, contains('日本語'), reason: 'Japanese paragraph missing');
        expect(text, contains("print('hello')"), reason: 'code block missing');
        expect(text, contains('ô hai'), reason: 'table cell missing');
        expect(text, contains('Đoạn cuối cùng'), reason: 'last block missing');
      });

      testWidgets('Vietnamese diacritics survive the round trip', (
        tester,
      ) async {
        await _pump(tester, mixedBlocks, layout: layout);
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
        await _pump(tester, mixedBlocks, layout: layout);
        final text = await _selectAllAndCopy(tester, clipboard);

        expect(text, isNotEmpty);
        expect(
          text,
          contains('void main() {'),
          reason: 'code block opening line missing',
        );
        // The indented line must still be indented, not collapsed.
        expect(
          text,
          contains("  print('hello');"),
          reason: 'code block indentation was lost in the clipboard text',
        );
      });
    });
  }

  group('the laziness / selection conflict', () {
    /// A document long enough that a lazy list cannot have built all of it.
    String longDocument() {
      final buffer = StringBuffer();
      for (var i = 1; i <= 300; i++) {
        buffer
          ..writeln('Paragraph $i, marker M$i.')
          ..writeln();
      }
      return buffer.toString();
    }

    testWidgets('a lazy list can only ever copy what is on screen', (
      tester,
    ) async {
      await _pump(
        tester,
        longDocument(),
        layout: ReaderLayout.lazyList,
        size: const Size(800, 600),
      );
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty, reason: 'nothing was selected at all');
      expect(text, contains('marker M1.'));
      expect(
        text,
        isNot(contains('marker M300.')),
        reason:
            'if this ever passes, laziness stopped being a problem for '
            'selection and doc 04 / doc 06 can both stand as written',
      );
    });

    testWidgets('an eager column copies the whole document', (tester) async {
      await _pump(
        tester,
        longDocument(),
        layout: ReaderLayout.eagerColumn,
        size: const Size(800, 600),
      );
      final text = await _selectAllAndCopy(tester, clipboard);

      expect(text, isNotEmpty, reason: 'nothing was selected at all');
      expect(text, contains('marker M1.'));
      expect(
        text,
        contains('marker M300.'),
        reason: 'the last paragraph was off screen but must still be copied',
      );
    });
  });

  group('dragging past the viewport edge', () {
    testWidgets('auto-scroll extends the selection into newly built blocks', (
      tester,
    ) async {
      // The realistic "select a long passage" flow. If a lazy list breaks the
      // selection as soon as new blocks build, laziness would be a problem for
      // ordinary use and not just for select-all.
      final buffer = StringBuffer();
      for (var i = 1; i <= 120; i++) {
        buffer
          ..writeln('Paragraph $i, marker M$i.')
          ..writeln();
      }

      await _pump(
        tester,
        buffer.toString(),
        layout: ReaderLayout.lazyList,
        size: const Size(800, 600),
      );

      final builtAtStart = find.byType(RichText).evaluate().length;

      // Press near the top, then drag well below the bottom edge and hold
      // there so the region auto-scrolls under the pointer.
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
      expect(
        text,
        isNotEmpty,
        reason: 'the drag selected nothing — the gesture never took',
      );
      // How far past the initially built region did the selection reach? The
      // anchor is wherever the press landed, not necessarily paragraph 1.
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
      // Contiguous: no gaps where a block scrolled in and was skipped.
      expect(
        reached.last - reached.first + 1,
        reached.length,
        reason: 'the selection has holes: $reached',
      );

      debugPrint(
        '>>> auto-scroll drag selected paragraphs '
        '${reached.first}..${reached.last} '
        '(${reached.length} of 120); $builtAtStart were built at press time',
      );
    });
  });

  group("candidate A's own selectable mode", () {
    testWidgets('builds one SelectableText island per block', (tester) async {
      // `selectable: true` makes MarkdownBuilder emit SelectableText.rich for
      // each block rather than wrapping the document in a SelectableRegion.
      // Every block is therefore its own independent selection.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeSelectableMarkdown(doc: _doc(mixedBlocks)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(SelectableText),
        findsWidgets,
        reason: 'selectable: true should produce SelectableText widgets',
      );
      expect(
        find.byType(SelectableRegion),
        findsNothing,
        reason: 'native mode is not SelectionArea-based',
      );
    });

    testWidgets('select-all inside it stops at the block boundary', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeSelectableMarkdown(doc: _doc(mixedBlocks)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click into the first block, then select all and copy.
      final first = find.byType(SelectableText).first;
      await tester.tapAt(tester.getCenter(first));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final text = clipboard.isEmpty ? '' : clipboard.last;
      expect(
        text,
        isNotEmpty,
        reason: 'nothing was copied — the block never took focus',
      );
      expect(text, contains('Chương một'), reason: 'wrong block was copied');
      expect(
        text,
        isNot(contains("print('hello')")),
        reason:
            'if this ever fails, native selectable started spanning blocks and '
            'is worth reconsidering against SelectionArea',
      );
    });
  });
}

DocModel _doc(String source) => DocModel(
  path: 'probe.md',
  sanitizedSource: source,
  outline: Outline.empty,
  blocks: const MarkdownPipeline()
      .parse(path: 'probe.md', bytes: source.codeUnits, isMdx: false)
      .blocks,
);

Future<void> _pump(
  WidgetTester tester,
  String source, {
  required ReaderLayout layout,
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
            builder: (context) => FlutterMarkdownPlusRenderer(
              layout: layout,
            ).build(context, _doc(source)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Selects everything with Ctrl+A and copies with Ctrl+C, returning whatever
/// reached the mocked clipboard.
Future<String> _selectAllAndCopy(
  WidgetTester tester,
  List<String> clipboard,
) async {
  // The region has to be focused before it will answer keyboard shortcuts, and
  // a mouse click is what a user would do.
  final target = find.byType(SelectableRegion).evaluate().isNotEmpty
      ? find.byType(SelectableRegion).first
      : find.byType(Scaffold).first;
  final gesture = await tester.startGesture(
    tester.getTopLeft(target) + const Offset(8, 8),
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
