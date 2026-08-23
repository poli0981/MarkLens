import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';

import '../test/fixtures/generators.dart';

/// S2's decisive measurement: what does whole-document selection cost?
///
/// The selection probe settled the behaviour — `SelectionArea` over an eager
/// column copies the entire document, a lazy list copies only what is on
/// screen, and candidate A's native `selectable` mode is per-block islands. So
/// meeting `docs/06_UI_UX.md` means building every block up front, and the
/// question is no longer *whether* laziness gives but *what it costs*.
///
/// The first attempt measured 1 MB eagerly and **killed the app** — the VM
/// service disappeared partway through, taking the run's report data with it.
/// So this version climbs a ladder of document sizes and appends each result
/// to a file as it goes: when the process dies, everything measured before it
/// died survives, and the last line written is the answer.
///
/// ```bash
/// flutter drive --profile \
///   --driver=test_driver/perf_driver.dart \
///   --target=integration_test/s2_eager_layout_test.dart \
///   -d windows
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  final ladder = File('build/s2_eager_ladder.md');

  setUpAll(() {
    ladder
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '# S2 — eager layout ladder (profile mode)\n\n'
        'cwd: ${Directory.current.path}\n\n'
        '| KB | layout | blocks | first paint | outcome |\n'
        '|--:|---|--:|--:|---|\n',
      );
  });

  // Ascending, so the threshold is known before anything dies.
  const sizesKb = <int>[100, 200, 400, 700, 1000];

  for (final kb in sizesKb) {
    for (final layout in ReaderLayout.values) {
      testWidgets('$kb KB — ${layout.name}', (tester) async {
        // Written before the measurement, so a hard crash still leaves a
        // record of what was being attempted when it happened.
        ladder.writeAsStringSync(
          '| $kb | ${layout.name} | ? | ? | started |\n',
          mode: FileMode.append,
        );

        final source = generateLargeDocument(targetCharacters: kb * 1024);
        final doc = const MarkdownPipeline().parse(
          path: 'perf/$kb.md',
          bytes: utf8.encode(source),
          isMdx: false,
        );

        var blocks = 0;
        final watch = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionArea(
                child: Builder(
                  builder: (context) => FlutterMarkdownPlusRenderer(
                    layout: layout,
                    onBlockCount: (n) => blocks = n,
                  ).build(context, doc),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        watch.stop();

        ladder.writeAsStringSync(
          '| $kb | ${layout.name} | $blocks | ${watch.elapsedMilliseconds} ms '
          '| survived |\n',
          mode: FileMode.append,
        );

        expect(find.byType(SelectionArea), findsOneWidget);
      });
    }
  }
}
