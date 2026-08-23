import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_widget_renderer.dart';

/// S1 fidelity probe (`docs/15_SPIKES_ROADMAP.md`).
///
/// Renders every torture-corpus page through both candidates and records what
/// each one actually produced. The point is evidence rather than assertions:
/// the report printed at the end is what the spike-results note is written
/// from. Only crashes are hard failures here — CLAUDE.md rule 9 applies to
/// both candidates equally.
void main() {
  const corpusRoot = 'test/fixtures/torture';
  const pipeline = MarkdownPipeline();
  final results = <_ProbeResult>[];

  final fixtures =
      Directory(corpusRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') || f.path.endsWith('.mdx'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final fixture in fixtures) {
    final relative = fixture.path.replaceAll(r'\', '/');
    final name = relative.substring(corpusRoot.length + 1);

    for (final candidate in _Candidate.values) {
      testWidgets('$name — ${candidate.label}', (tester) async {
        final doc = pipeline.parse(
          path: relative,
          bytes: fixture.readAsBytesSync(),
          isMdx: relative.endsWith('.mdx'),
        );

        final result = await _render(tester, candidate, doc, name);
        results.add(result);

        expect(
          result.crashed,
          isFalse,
          reason:
              '${candidate.label} threw on $name: ${result.error}\n'
              'No document may crash the renderer (CLAUDE.md rule 9).',
        );
      });
    }
  }

  tearDownAll(() => _report(results));
}

enum _Candidate {
  flutterMarkdownPlus('flutter_markdown_plus'),
  markdownWidget('markdown_widget');

  const _Candidate(this.label);
  final String label;
}

Future<_ProbeResult> _render(
  WidgetTester tester,
  _Candidate candidate,
  DocModel doc,
  String name,
) async {
  // A tall viewport so the whole document builds and the census sees every
  // block, not just the ones that happen to be on screen.
  tester.view
    ..physicalSize = const Size(1400, 40000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var blockCount = -1;
  void countBlocks(int n) => blockCount = n;

  final renderer = switch (candidate) {
    _Candidate.flutterMarkdownPlus => FlutterMarkdownPlusRenderer(
      onBlockCount: countBlocks,
    ),
    _Candidate.markdownWidget => MarkdownWidgetRenderer(
      onBlockCount: countBlocks,
    ),
  };

  Object? error;
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => renderer.build(context, doc)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  } on Object catch (e) {
    error = e;
  }
  error ??= tester.takeException();

  return _ProbeResult(
    fixture: name,
    candidate: candidate,
    blocks: blockCount,
    error: error,
    tables: _count<Table>(),
    checkboxes: _count<Checkbox>(),
    images: _count<Image>() + _count<Placeholder>(),
    richTexts: _count<RichText>(),
    scrollables: _count<Scrollable>(),
  );
}

int _count<T extends Widget>() => find.byType(T).evaluate().length;

class _ProbeResult {
  _ProbeResult({
    required this.fixture,
    required this.candidate,
    required this.blocks,
    required this.error,
    required this.tables,
    required this.checkboxes,
    required this.images,
    required this.richTexts,
    required this.scrollables,
  });

  final String fixture;
  final _Candidate candidate;
  final int blocks;
  final Object? error;
  final int tables;
  final int checkboxes;
  final int images;
  final int richTexts;
  final int scrollables;

  bool get crashed => error != null;
}

void _report(List<_ProbeResult> results) {
  final byFixture = <String, Map<_Candidate, _ProbeResult>>{};
  for (final r in results) {
    byFixture.putIfAbsent(r.fixture, () => {})[r.candidate] = r;
  }

  final buffer = StringBuffer()
    ..writeln()
    ..writeln('## S1 fidelity probe')
    ..writeln()
    ..writeln(
      '| Fixture | A blocks | A tables | A checks | A text | '
      'B blocks | B tables | B checks | B text | Notes |',
    )
    ..writeln('|---|--:|--:|--:|--:|--:|--:|--:|--:|---|');

  for (final fixture in byFixture.keys.toList()..sort()) {
    final a = byFixture[fixture]![_Candidate.flutterMarkdownPlus];
    final b = byFixture[fixture]![_Candidate.markdownWidget];
    final notes = <String>[
      if (a?.crashed ?? false) 'A THREW',
      if (b?.crashed ?? false) 'B THREW',
      if (a != null && b != null && a.blocks != b.blocks) 'block count differs',
    ];
    buffer.writeln(
      '| $fixture '
      '| ${a?.blocks} | ${a?.tables} | ${a?.checkboxes} | ${a?.richTexts} '
      '| ${b?.blocks} | ${b?.tables} | ${b?.checkboxes} | ${b?.richTexts} '
      '| ${notes.join(', ')} |',
    );
  }

  debugPrint(buffer.toString());
  File(
    'build/s1_fidelity_probe.md',
  ).writeAsStringSync(buffer.toString());
}
