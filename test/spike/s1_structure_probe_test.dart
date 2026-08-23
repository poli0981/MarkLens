import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/outline.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_widget_renderer.dart';

/// S1's three structural questions (`docs/15_SPIKES_ROADMAP.md`), answered with
/// measurements rather than opinion.
void main() {
  /// Five unambiguous top-level blocks: heading, paragraph, list, code, table.
  const fiveBlocks = '''
# Heading

A paragraph.

- one
- two

```dart
void main() {}
```

| A | B |
|---|---|
| 1 | 2 |
''';

  const emptyHeading = '''
# H

#

# H2
''';

  const blockHtml = '''
# H

<div>block html</div>

# H2
''';

  const withReference = '''
See [the reference][ref] and a footnote.[^1]

[ref]: https://example.com
[^1]: The footnote text.
''';

  const isolatedParagraph = 'See [the reference][ref] and a footnote.[^1]';

  group('Q1 — does the renderer block list map onto source blocks?', () {
    testWidgets('candidate A returns 2N-1 entries, not N', (tester) async {
      final counts = await _blockCounts(tester, fiveBlocks);

      expect(
        counts.a,
        9,
        reason: 'five real blocks plus four SizedBox spacers',
      );
      expect(
        counts.b,
        5,
        reason: 'markdown_widget returns one entry per block',
      );
    });

    testWidgets('A puts a spacer at every odd index', (tester) async {
      final blocks = await _captureBlocks(tester, fiveBlocks, _Candidate.a);
      for (var i = 1; i < blocks.length; i += 2) {
        expect(
          blocks[i],
          isA<SizedBox>(),
          reason: 'index $i should be a block spacer',
        );
      }
    });

    testWidgets('but a real block can also be a SizedBox', (tester) async {
      // An empty heading is a real block that renders as `const SizedBox()`,
      // so "drop the SizedBoxes" is NOT a safe way to recover the block list.
      // Index arithmetic is the only correct mapping.
      final blocks = await _captureBlocks(tester, emptyHeading, _Candidate.a);

      expect(blocks.length, 5, reason: 'three blocks plus two spacers');
      expect(
        blocks[2],
        isA<SizedBox>(),
        reason: 'the empty heading is a real block rendered as a SizedBox',
      );
    });

    testWidgets('candidate A silently drops block HTML', (tester) async {
      // docs/04 requires block HTML to become a collapsed
      // "Raw HTML (not rendered)" box. flutter_markdown_plus emits nothing at
      // all for it, so the content disappears without a trace. Whatever S1
      // picks, this has to be built on top rather than assumed.
      final blocks = await _captureBlocks(tester, blockHtml, _Candidate.a);

      expect(
        blocks.length,
        3,
        reason: 'two headings plus one spacer — the div produced no block',
      );
      expect(
        await _renderedText(tester, blockHtml, _Candidate.a),
        isNot(contains('block html')),
        reason: 'the HTML content vanished rather than being shown escaped',
      );
    });
  });

  group('Q2 — per-document parse vs per-block parse', () {
    testWidgets('parsing the whole document resolves the reference', (
      tester,
    ) async {
      final text = await _renderedText(tester, withReference, _Candidate.a);
      expect(text, contains('the reference'));
      expect(
        text,
        isNot(contains('[ref]')),
        reason: 'the reference definition should have been consumed',
      );
    });

    testWidgets('parsing that paragraph alone breaks the reference', (
      tester,
    ) async {
      // This is why "one widget per block" must mean per-block *widgets from
      // one parse*, never per-block parsing.
      final text = await _renderedText(
        tester,
        isolatedParagraph,
        _Candidate.a,
      );
      expect(
        text,
        contains('[ref]'),
        reason: 'an isolated block cannot see the definition below it',
      );
    });
  });

  group('Q3 — SelectionArea over a lazy list', () {
    testWidgets('offscreen blocks are never built, so cannot be selected', (
      tester,
    ) async {
      final source = StringBuffer();
      for (var i = 1; i <= 200; i++) {
        source
          ..writeln('Paragraph number $i, unique marker P$i.')
          ..writeln();
      }

      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionArea(
              child: Builder(
                builder: (context) => const FlutterMarkdownPlusRenderer().build(
                  context,
                  _doc(source.toString()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final built = find.byType(RichText).evaluate().length;
      expect(
        built,
        lessThan(200),
        reason: 'the list should be lazy, so far fewer than 200 are built',
      );

      // The last paragraph exists in the source but not in the widget tree —
      // a SelectionArea has nothing to select there.
      expect(find.textContaining('marker P200.'), findsNothing);
      expect(find.textContaining('marker P1.'), findsOneWidget);
    });
  });
}

enum _Candidate { a, b }

DocModel _doc(String source) => DocModel(
  path: 'probe.md',
  sanitizedSource: source,
  outline: Outline.empty,
  blocks: const MarkdownPipeline()
      .parse(path: 'probe.md', bytes: source.codeUnits, isMdx: false)
      .blocks,
);

Future<({int a, int b})> _blockCounts(
  WidgetTester tester,
  String source,
) async {
  var a = -1;
  var b = -1;
  await _pump(tester, source, _Candidate.a, onCount: (n) => a = n);
  await _pump(tester, source, _Candidate.b, onCount: (n) => b = n);
  return (a: a, b: b);
}

Future<List<Widget>> _captureBlocks(
  WidgetTester tester,
  String source,
  _Candidate candidate,
) async {
  await _pump(tester, source, candidate);
  final listView = tester.widget<ListView>(find.byType(ListView));
  final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
  final context = tester.element(find.byType(ListView));
  return <Widget>[
    for (var i = 0; i < (delegate.childCount ?? 0); i++)
      delegate.builder(context, i)!,
  ];
}

Future<String> _renderedText(
  WidgetTester tester,
  String source,
  _Candidate candidate,
) async {
  await _pump(tester, source, candidate);
  final buffer = StringBuffer();
  for (final element in find.byType(RichText).evaluate()) {
    buffer.writeln((element.widget as RichText).text.toPlainText());
  }
  return buffer.toString();
}

Future<void> _pump(
  WidgetTester tester,
  String source,
  _Candidate candidate, {
  void Function(int)? onCount,
}) async {
  tester.view
    ..physicalSize = const Size(1400, 20000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final renderer = switch (candidate) {
    _Candidate.a => FlutterMarkdownPlusRenderer(onBlockCount: onCount),
    _Candidate.b => MarkdownWidgetRenderer(onBlockCount: onCount),
  };

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => renderer.build(context, _doc(source)),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}
