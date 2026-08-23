import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_renderer.dart';
import 'package:marklens/features/reader/rendering/markdown_widget_renderer.dart';

import '../test/fixtures/generators.dart';

/// S1's scroll gate: the 1 MB torture document must average **>= 55 fps**
/// (`docs/00_CHARTER.md`), which is 18.18 ms per frame.
///
/// Widget tests cannot answer this — they drive a fake clock, so there are no
/// real frames to time. This runs the real engine in profile mode:
///
/// ```bash
/// flutter drive --profile \
///   --driver=test_driver/perf_driver.dart \
///   --target=integration_test/s1_scroll_perf_test.dart \
///   -d windows
/// ```
///
/// The driver writes `build/<candidate>.timeline_summary.json`. Debug mode is
/// meaningless here: assertions and the interpreter make every frame several
/// times slower than what a user would see.
///
/// `flutter drive` prints "integration_test plugin was not detected" on
/// desktop. That is expected and harmless — the plugin only has Android and
/// iOS implementations, and on desktop the results reach the driver over the
/// VM service instead. Do not chase it.
///
/// **Scrolling is driven through the `ScrollController`, not `tester.fling`.**
/// The first version of this harness used flings, and they moved the list by
/// exactly zero pixels — producing a confident-looking "1078 fps" measured
/// entirely on a stationary list. The assertion at the end of [_measureScroll]
/// exists so that failure can never be silent again.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Without this the binding only pumps a frame when something asks for
    // one. benchmarkLive pumps continuously and asserts we are not in debug.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  late DocModel largeDoc;

  setUpAll(() {
    final source = generateLargeDocument();
    largeDoc = const MarkdownPipeline().parse(
      path: 'perf/large.md',
      bytes: utf8.encode(source),
      isMdx: false,
    );
  });

  testWidgets('candidate A — flutter_markdown_plus scrolls 1 MB', (
    tester,
  ) async {
    await _measureScroll(
      tester,
      binding,
      largeDoc,
      reportKey: 'flutter_markdown_plus',
      makeRenderer: (controller) =>
          FlutterMarkdownPlusRenderer(controller: controller),
    );
  });

  testWidgets('candidate B — markdown_widget scrolls 1 MB', (tester) async {
    await _measureScroll(
      tester,
      binding,
      largeDoc,
      reportKey: 'markdown_widget',
      makeRenderer: (controller) =>
          MarkdownWidgetRenderer(controller: controller),
    );
  });

  // docs/00_CHARTER.md also budgets < 150 ms to first paint for a *typical*
  // 100 KB document. Same harness, same profile build, so it costs one extra
  // pump to close that criterion too.
  testWidgets('first paint of a typical 100 KB document', (tester) async {
    final source = generateLargeDocument(targetCharacters: 100 * 1024);
    final doc = const MarkdownPipeline().parse(
      path: 'perf/typical.md',
      bytes: utf8.encode(source),
      isMdx: false,
    );

    final controller = ScrollController();
    addTearDown(controller.dispose);

    final watch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                FlutterMarkdownPlusRenderer(controller: controller)
                    .build(context, doc),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(_oneFrame);
    watch.stop();

    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['typical_100kb_first_paint_ms'] =
        watch.elapsedMilliseconds;

    expect(find.byType(ListView), findsOneWidget);
  });
}

/// One frame at 60 Hz. `pumpAndSettle` defaults to 100 ms steps, which is too
/// coarse to leave frames worth measuring in the trace.
const _oneFrame = Duration(milliseconds: 16);

/// How far each scroll segment travels, and how long it takes.
///
/// 5000 px in 500 ms is roughly a hard flick, and repeating it keeps new
/// blocks coming into view for the whole trace rather than measuring one
/// screenful over and over.
const _segmentPixels = 5000.0;
const _segmentDuration = Duration(milliseconds: 500);

/// Segments run at each anchor, down and then back up.
const _segmentsPerAnchor = 4;

/// Where in the document to sample, as a fraction of the scroll extent.
///
/// A realistic flick covers ~5000 px, so scrolling continuously from the top
/// would only ever measure the first few percent of a 900,000 px document.
/// Jumping to four depths and doing realistic scrolls at each keeps both the
/// velocity honest and the coverage wide.
const _anchors = <double>[0, 0.25, 0.5, 0.75];

Future<void> _measureScroll(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  DocModel doc, {
  required String reportKey,
  required MarkdownRenderer Function(ScrollController) makeRenderer,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);

  final firstPaint = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => makeRenderer(controller).build(context, doc),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(_oneFrame);
  firstPaint.stop();

  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['${reportKey}_first_paint_ms'] =
      firstPaint.elapsedMilliseconds;

  expect(find.byType(ListView), findsOneWidget);

  var engineFrames = 0;
  void countFrames(List<FrameTiming> timings) => engineFrames += timings.length;
  SchedulerBinding.instance.addTimingsCallback(countFrames);
  addTearDown(
    () => SchedulerBinding.instance.removeTimingsCallback(countFrames),
  );

  final maxExtent = controller.position.maxScrollExtent;
  var furthest = 0.0;
  var scrolled = 0.0;

  await binding.traceAction(
    () async {
      for (final anchor in _anchors) {
        final base = maxExtent * anchor;
        // Teleport to the sample point; the jump itself is one frame and is
        // not what the average is about.
        controller.jumpTo(base);
        await tester.pumpAndSettle(_oneFrame);

        // Down, then back up: the return trip re-lays-out blocks that already
        // scrolled off, which is a different cost from building them fresh.
        for (var i = 1; i <= _segmentsPerAnchor; i++) {
          await _scrollTo(
            tester,
            controller,
            base + i * _segmentPixels,
            maxExtent,
          );
          if (controller.offset > furthest) {
            furthest = controller.offset;
          }
          scrolled += _segmentPixels;
        }
        for (var i = _segmentsPerAnchor - 1; i >= 0; i--) {
          await _scrollTo(
            tester,
            controller,
            base + i * _segmentPixels,
            maxExtent,
          );
          scrolled += _segmentPixels;
        }
      }
    },
    // NOT the default 'all'. With every stream on, a twenty-second trace fills
    // the VM's ring buffer with GC and compiler noise and the earliest events
    // are dropped — the summary then saw 21 frames out of 1356 actually
    // rendered. TimelineSummary only needs 'Frame' (Dart) and the rasterizer
    // draw events (Embedder). The names are the VM service's, so they are
    // capitalised — lowercase gets rejected with "invalid 'recordedStreams'".
    streams: const <String>['Dart', 'Embedder'],
    reportKey: '${reportKey}_timeline',
  );

  binding.reportData!['${reportKey}_diagnostics'] = <String, dynamic>{
    'max_scroll_extent': maxExtent,
    'furthest_offset': furthest,
    'pixels_scrolled': scrolled,
    'deepest_sample_fraction': _anchors.last,
    'engine_frames': engineFrames,
  };

  // The gate is meaningless if the list never moved. This is the assertion the
  // fling version needed and did not have.
  final expected = _segmentPixels * _segmentsPerAnchor * 2 * _anchors.length;
  expect(
    scrolled,
    greaterThan(expected * 0.9),
    reason:
        'the list travelled $scrolled px of an expected $expected, so any fps '
        'figure from this run describes a stationary list',
  );
}

Future<void> _scrollTo(
  WidgetTester tester,
  ScrollController controller,
  double target,
  double maxExtent,
) async {
  // Deliberately not awaited: pumpAndSettle drives the frames the animation
  // needs, and awaiting here first would deadlock.
  controller.animateTo(
    target.clamp(0.0, maxExtent),
    duration: _segmentDuration,
    curve: Curves.linear,
  );
  await tester.pumpAndSettle(_oneFrame);
}
