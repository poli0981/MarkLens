@Tags(['watcher-live'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watcher/watcher.dart';

/// S5 — what the `watcher` package actually reports when an editor saves.
///
/// The editors themselves are not installed here, so instead of guessing at
/// their event sequences this reproduces the **filesystem operations** each
/// one is known to perform, against a real directory on this machine's real
/// filesystem, and records what comes out. The normalizer is then written
/// against observed sequences rather than assumed ones — and the remaining
/// gap (does VS Code really do pattern P2?) is a question the maintainer can
/// answer in one save.
///
/// Tagged `watcher-live`: it touches the disk and sleeps in real time, so it
/// is excluded from the ordinary suite.
///
/// ```bash
/// flutter test --tags watcher-live test/spike/s5_watch_observation_test.dart
/// ```
void main() {
  late Directory root;
  late File doc;
  final report = StringBuffer();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('marklens_s5_');
    doc = File('${root.path}${Platform.pathSeparator}note.md');
    await doc.writeAsString('# Original\n');
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  tearDownAll(() {
    debugPrint('\n$report');
    File('build/s5_observations.md').writeAsStringSync(report.toString());
  });

  /// Runs [save] while watching [root], and records every event that arrives.
  Future<List<_Observed>> observe(
    String label,
    Future<void> Function() save,
  ) async {
    final watcher = DirectoryWatcher(root.path);
    final events = <_Observed>[];
    final clock = Stopwatch();

    final sub = watcher.events.listen((event) {
      events.add(
        _Observed(
          type: event.type.toString(),
          path: event.path.split(Platform.pathSeparator).last,
          atMs: clock.elapsedMilliseconds,
        ),
      );
    });
    await watcher.ready;

    clock.start();
    await save();
    // Long enough to catch a late or duplicated event, and to notice if a
    // pattern produces a trailing REMOVE that would show a false "missing".
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await sub.cancel();

    report
      ..writeln('### $label')
      ..writeln();
    if (events.isEmpty) {
      report.writeln('- **no events at all**');
    } else {
      for (final e in events) {
        report.writeln('- ${e.atMs} ms  ${e.type}  ${e.path}');
      }
    }
    report.writeln();
    return events;
  }

  group('save patterns on this filesystem', () {
    test('P1 — write in place (Notepad++, VS Code default)', () async {
      final events = await observe('P1 write in place', () async {
        await doc.writeAsString('# Edited in place\n');
      });

      expect(events, isNotEmpty, reason: 'the watcher saw nothing at all');
      expect(
        events.last.path,
        'note.md',
        reason: 'the last event should concern the document itself',
      );
    });

    test('P2 — temp file then rename over (atomic replace)', () async {
      final temp = File('${root.path}${Platform.pathSeparator}note.md.tmp');
      final events = await observe('P2 temp + rename over', () async {
        await temp.writeAsString('# Replaced atomically\n');
        await temp.rename(doc.path);
      });

      expect(events, isNotEmpty);
      expect(
        doc.existsSync(),
        isTrue,
        reason: 'the document must exist after an atomic replace',
      );
    });

    test('P3 — delete then recreate', () async {
      final events = await observe('P3 delete + recreate', () async {
        await doc.delete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await doc.writeAsString('# Recreated\n');
      });

      expect(events, isNotEmpty);
      expect(doc.existsSync(), isTrue);
    });

    test('P4 — rename away to a backup, then write a new file (vim)', () async {
      final backup = File('${root.path}${Platform.pathSeparator}note.md~');
      final events = await observe('P4 rename to backup + new file', () async {
        await doc.rename(backup.path);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await File(doc.path).writeAsString('# Written fresh\n');
      });

      expect(events, isNotEmpty);
      expect(doc.existsSync(), isTrue);
    });

    test('P5 — several rapid writes (autosave)', () async {
      final events = await observe('P5 rapid writes', () async {
        for (var i = 0; i < 5; i++) {
          await doc.writeAsString('# Autosave $i\n');
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
      });

      expect(events, isNotEmpty);
    });

    test('P6 — a genuine deletion, which must NOT look like a save', () async {
      final events = await observe('P6 real deletion', () async {
        await doc.delete();
      });

      expect(events, isNotEmpty);
      expect(
        doc.existsSync(),
        isFalse,
        reason: 'this is the one case that really is missing',
      );
    });
  });

  group('the platform watcher itself', () {
    test(
      'a directory watcher reports the file, not just the directory',
      () async {
        final events = await observe('sanity: single write', () async {
          await doc.writeAsString('# Sanity\n');
        });

        expect(
          events.map((e) => e.path),
          contains('note.md'),
          reason:
              'if the watcher only reports the directory, every classification '
              'below has to be rebuilt around mtime sweeps instead',
        );
      },
    );

    test('FileWatcher on Windows is polling, and how slow it is', () async {
      // docs/07 says "individual file watchers for ad-hoc files". On Windows
      // File.watch does not work, so the package silently falls back to
      // PollingFileWatcher with a one-second period — twice the 500 ms budget
      // in doc 15. This measures the real latency rather than trusting that.
      final watcher = FileWatcher(doc.path);
      final firstEvent = Completer<int>();
      final clock = Stopwatch();
      final sub = watcher.events.listen((_) {
        if (!firstEvent.isCompleted) {
          firstEvent.complete(clock.elapsedMilliseconds);
        }
      });
      await watcher.ready;

      clock.start();
      await doc.writeAsString('# Poll me\n');

      final latency = await firstEvent.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
      await sub.cancel();

      report
        ..writeln('### FileWatcher latency (${Platform.operatingSystem})')
        ..writeln()
        ..writeln('- implementation: ${watcher.runtimeType}')
        ..writeln('- first event after: $latency ms')
        ..writeln('- doc 15 budget: 500 ms')
        ..writeln();

      expect(latency, isNot(-1), reason: 'no event arrived within 5 seconds');
    });
  });
}

class _Observed {
  _Observed({required this.type, required this.path, required this.atMs});

  final String type;
  final String path;
  final int atMs;
}
