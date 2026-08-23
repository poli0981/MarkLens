import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_widget_renderer.dart';

import '../fixtures/generators.dart';

/// S1 cost probe on the 1 MB torture document.
///
/// **These numbers are debug-mode.** Flutter debug builds run interpreted with
/// assertions on, so the absolute figures are an upper bound several times
/// worse than release. What they are good for is the *ratio* between the two
/// candidates and between the pipeline and the renderer, measured under
/// identical conditions — which is the part S1 needs.
///
/// The >= 55 fps scroll gate from `docs/00_CHARTER.md` is not measurable here:
/// widget tests drive a fake clock, so there are no real frames to time. That
/// gate needs a profile-mode run on the reference machine and stays open.
void main() {
  late String largeSource;
  late DocModel largeDoc;
  final report = StringBuffer();

  setUpAll(() {
    largeSource = generateLargeDocument();
    largeDoc = _parseTimed(largeSource, report);
  });

  testWidgets('candidate A builds the 1 MB document', (tester) async {
    final result = await _timeRender(
      tester,
      largeDoc,
      (onCount) => FlutterMarkdownPlusRenderer(onBlockCount: onCount),
    );
    _record(report, 'flutter_markdown_plus', result);
    expect(result.blocks, greaterThan(0));
  });

  testWidgets('candidate B builds the 1 MB document', (tester) async {
    final result = await _timeRender(
      tester,
      largeDoc,
      (onCount) => MarkdownWidgetRenderer(onBlockCount: onCount),
    );
    _record(report, 'markdown_widget', result);
    expect(result.blocks, greaterThan(0));
  });

  testWidgets('a 100 KB document is the realistic first-paint case', (
    tester,
  ) async {
    // docs/00_CHARTER.md budgets < 150 ms to first paint for a typical 100 KB
    // document. Debug mode cannot confirm the budget, but it can show how the
    // cost scales away from the 1 MB worst case.
    final source = generateLargeDocument(targetCharacters: 100 * 1024);
    final doc = _parseTimed(source, report, label: 'pipeline.parse (100 KB)');
    final result = await _timeRender(
      tester,
      doc,
      (onCount) => FlutterMarkdownPlusRenderer(onBlockCount: onCount),
    );
    _record(report, 'flutter_markdown_plus @100 KB', result);
    expect(result.blocks, greaterThan(0));
  });

  tearDownAll(() {
    final text =
        '''
## S1 cost probe (DEBUG MODE — upper bounds, ratios are the signal)

$report
Source: ${utf8.encode(largeSource).length} bytes of UTF-8.
''';
    debugPrint(text);
    File('build/s1_perf_probe.md').writeAsStringSync(text);
  });
}

DocModel _parseTimed(
  String source,
  StringBuffer report, {
  String label = 'pipeline.parse (1 MB)',
}) {
  const pipeline = MarkdownPipeline();
  final bytes = utf8.encode(source);
  final watch = Stopwatch()..start();
  final doc = pipeline.parse(path: 'perf.md', bytes: bytes, isMdx: false);
  watch.stop();
  report.writeln('- $label: ${watch.elapsedMilliseconds} ms');
  return doc;
}

class _RenderResult {
  _RenderResult({
    required this.blocks,
    required this.buildMs,
    required this.pumpMs,
  });

  final int blocks;
  final int buildMs;
  final int pumpMs;
}

Future<_RenderResult> _timeRender(
  WidgetTester tester,
  DocModel doc,
  MarkdownRenderer Function(void Function(int)) makeRenderer,
) async {
  tester.view
    ..physicalSize = const Size(1400, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var blocks = 0;
  final buildWatch = Stopwatch();
  final renderer = makeRenderer((n) => blocks = n);

  final pumpWatch = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            buildWatch.start();
            final widget = renderer.build(context, doc);
            buildWatch.stop();
            return widget;
          },
        ),
      ),
    ),
  );
  await tester.pump();
  pumpWatch.stop();

  return _RenderResult(
    blocks: blocks,
    buildMs: buildWatch.elapsedMilliseconds,
    pumpMs: pumpWatch.elapsedMilliseconds,
  );
}

void _record(StringBuffer report, String label, _RenderResult result) {
  final construction = result.buildMs == 0
      ? 'construction folded into the pump'
      : 'construction ${result.buildMs} ms';
  report.writeln(
    '- $label: ${result.blocks} block widgets, $construction, '
    'first pump ${result.pumpMs} ms',
  );
}
