import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Driver for the S1 scroll gate (`integration_test/s1_scroll_perf_test.dart`).
///
/// Turns each traced timeline into a summary next to the raw trace, then prints
/// the one number the gate is about: average frames per second, against the
/// >= 55 fps floor in `docs/00_CHARTER.md`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) {
      stderr.writeln('No report data — did the test run?');
      return;
    }

    final verdicts = <String>[];

    for (final entry in data.entries) {
      if (!entry.key.endsWith('_timeline')) continue;
      final candidate = entry.key.replaceAll('_timeline', '');

      final timeline = driver.Timeline.fromJson(
        entry.value as Map<String, dynamic>,
      );
      final summary = driver.TimelineSummary.summarize(timeline);

      // The VM's timeline is a ring buffer sized in bytes, not seconds, so a
      // long trace keeps only its tail. Measuring the captured span makes that
      // visible instead of leaving a low frame count looking like a bug.
      final micros =
          (timeline.events ?? const <driver.TimelineEvent>[])
              .map((e) => e.timestampMicros)
              .whereType<int>()
              .toList()
            ..sort();
      final spanMs = micros.isEmpty ? 0 : (micros.last - micros.first) ~/ 1000;
      await summary.writeTimelineToFile(candidate, pretty: true);

      final json = summary.summaryJson;
      final avgBuild = json['average_frame_build_time_millis'] as double? ?? 0;
      final avgRaster =
          json['average_frame_rasterizer_time_millis'] as double? ?? 0;
      final worst = avgBuild > avgRaster ? avgBuild : avgRaster;
      final fps = worst > 0 ? 1000 / worst : double.infinity;
      final frameCount = json['frame_count'] as int? ?? 0;

      final diagnostics = data['${candidate}_diagnostics'];
      stdout.writeln('diagnostics[$candidate]: $diagnostics');

      verdicts.add(
        _line(
          candidate: candidate,
          firstPaintMs: data['${candidate}_first_paint_ms'],
          avgBuild: avgBuild,
          avgRaster: avgRaster,
          p90Build: json['90th_percentile_frame_build_time_millis'] as double?,
          p99Build: json['99th_percentile_frame_build_time_millis'] as double?,
          missedBuild: json['missed_frame_build_budget_count'],
          missedRaster: json['missed_frame_rasterizer_budget_count'],
          frames: frameCount,
          capturedSpanMs: spanMs,
          fps: fps,
        ),
      );
    }

    final typical = data['typical_100kb_first_paint_ms'];
    final typicalVerdict = typical is int
        ? '${typical <= 150 ? 'PASS' : 'FAIL'} ($typical ms, budget 150 ms)'
        : 'not measured';

    final report = StringBuffer()
      ..writeln()
      ..writeln('## S1 scroll gate — profile mode, 1 MB document')
      ..writeln()
      ..writeln('Gate: >= 55 fps average (18.18 ms/frame), docs/00_CHARTER.md')
      ..writeln()
      ..writeln('First paint, typical 100 KB document: $typicalVerdict')
      ..writeln()
      ..writeAll(verdicts, '\n');

    stdout.writeln(report);
    File('build/s1_scroll_gate.md').writeAsStringSync(report.toString());
  },
);

/// Minimum sample size for the average to mean anything.
///
/// 200 frames is a little over three seconds of continuous 60 Hz animation.
/// The floor is not higher because the VM's timeline ring buffer is sized in
/// bytes: lengthening the trace does not increase the captured frame count, it
/// only moves the captured window later. Runs of 12 and 24 segments both
/// captured 254 frames for candidate A, which is what that looks like.
///
/// The failure this guard originally existed for — measuring a list that never
/// moved — is now caught directly by the `pixels_scrolled` assertion in the
/// test, which is a better check than a frame count ever was.
const minimumFramesForAVerdict = 200;

String _line({
  required String candidate,
  required Object? firstPaintMs,
  required double avgBuild,
  required double avgRaster,
  required double? p90Build,
  required double? p99Build,
  required Object? missedBuild,
  required Object? missedRaster,
  required Object? frames,
  required int capturedSpanMs,
  required double fps,
}) {
  final String verdict;
  if ((frames as int? ?? 0) < minimumFramesForAVerdict) {
    verdict =
        'INCONCLUSIVE (only $frames frames — need '
        '$minimumFramesForAVerdict; check the binding frame policy)';
  } else {
    verdict = '${fps >= 55 ? 'PASS' : 'FAIL'} (${fps.toStringAsFixed(1)} fps)';
  }
  return const JsonEncoder.withIndent('  ').convert({
    'candidate': candidate,
    'verdict': verdict,
    'first_paint_ms': firstPaintMs,
    'frames': frames,
    'captured_span_ms': capturedSpanMs,
    'avg_frame_build_ms': avgBuild,
    'avg_frame_raster_ms': avgRaster,
    'p90_frame_build_ms': p90Build,
    'p99_frame_build_ms': p99Build,
    'missed_build_budget': missedBuild,
    'missed_raster_budget': missedRaster,
  });
}
