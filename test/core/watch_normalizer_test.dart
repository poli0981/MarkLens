import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/watch/watch_normalizer.dart';

/// `docs/12_TESTING.md`: WatchService event normalization, with the synthetic
/// delete+create and rename sequences becoming a single `changed`.
///
/// The sequences and their gaps are the ones spike S5 actually measured on
/// Windows/NTFS, not invented ones — see
/// `docs/spike-results/S5-watcher.md`.
void main() {
  /// Collects normalized output for a scripted burst of raw events.
  ///
  /// [script] is a list of `(delayMs, path)` pairs replayed in order, and
  /// [existsAfter] is what the filesystem would say once the dust settles.
  Future<List<WatchEvent>> run(
    List<(int, String)> script, {
    required Set<String> existsAfter,
    Duration debounce = const Duration(milliseconds: 200),
    Duration settleFor = const Duration(milliseconds: 400),
  }) async {
    final normalizer = WatchNormalizer(
      pathExists: existsAfter.contains,
      debounce: debounce,
    );
    addTearDown(normalizer.dispose);

    final seen = <WatchEvent>[];
    final sub = normalizer.events.listen(seen.add);

    for (final (delayMs, path) in script) {
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      normalizer.add(path);
    }
    await Future<void>.delayed(settleFor);
    await sub.cancel();
    return seen;
  }

  group('the six save patterns S5 measured', () {
    test('P1 write in place — one changed', () async {
      final events = await run(
        <(int, String)>[(10, 'note.md')],
        existsAfter: {'note.md'},
      );

      expect(events, hasLength(1));
      expect(events.single.kind, WatchEventKind.changed);
    });

    test('P2 temp + rename over — one changed', () async {
      // Arrives as a single modify on Windows; the package already collapsed
      // the rename.
      final events = await run(
        <(int, String)>[(14, 'note.md')],
        existsAfter: {'note.md'},
      );

      expect(events, hasLength(1));
      expect(events.single.kind, WatchEventKind.changed);
    });

    test('P3 delete + recreate — one changed, never a missing', () async {
      // remove at 7 ms, add at 28 ms. The remove alone is indistinguishable
      // from a real deletion, so nothing may be emitted until the window
      // closes — this is the false-badge case doc 15 calls out.
      final events = await run(
        <(int, String)>[(7, 'note.md'), (21, 'note.md')],
        existsAfter: {'note.md'},
      );

      expect(events, hasLength(1), reason: 'a missing must not flash first');
      expect(events.single.kind, WatchEventKind.changed);
    });

    test('P4 vim rename away + rewrite — one changed', () async {
      // remove note.md at 8 ms, add note.md~ at 8 ms, add note.md at 29 ms.
      // The backup is a separate path and is filtered by the extension
      // registry upstream, but the normalizer must keep the two apart anyway.
      final events = await run(
        <(int, String)>[(8, 'note.md'), (0, 'note.md~'), (21, 'note.md')],
        existsAfter: {'note.md', 'note.md~'},
      );

      expect(events, hasLength(2), reason: 'two distinct paths were touched');
      expect(
        events.where((e) => e.path == 'note.md').single.kind,
        WatchEventKind.changed,
      );
    });

    test('P5 five rapid writes — collapsed to one changed', () async {
      final events = await run(
        <(int, String)>[
          (6, 'note.md'),
          (33, 'note.md'),
          (31, 'note.md'),
          (32, 'note.md'),
          (33, 'note.md'),
        ],
        existsAfter: {'note.md'},
      );

      expect(events, hasLength(1), reason: 'autosave should not thrash');
      expect(events.single.kind, WatchEventKind.changed);
    });

    test('P6 real deletion — one missing', () async {
      final events = await run(
        <(int, String)>[(7, 'note.md')],
        existsAfter: <String>{},
      );

      expect(events, hasLength(1));
      expect(events.single.kind, WatchEventKind.missing);
    });
  });

  group('classification is by existence, not by event kind', () {
    test('an add that leaves nothing behind still reports missing', () async {
      // A file created and immediately removed inside one window. The last
      // raw event says "add", but the truth is that it is gone.
      final events = await run(
        <(int, String)>[(0, 'gone.md'), (10, 'gone.md')],
        existsAfter: <String>{},
      );

      expect(events.single.kind, WatchEventKind.missing);
    });

    test('a deletion followed by a late recreation reports both', () async {
      // Past the debounce window this is genuinely two things: the document
      // went away, and later came back. The badge appearing and then clearing
      // is correct here, unlike P3 where the gap is 28 ms.
      final normalizer = WatchNormalizer(
        pathExists: (_) => _fileIsBack,
        debounce: const Duration(milliseconds: 60),
      );
      addTearDown(normalizer.dispose);

      final seen = <WatchEvent>[];
      final sub = normalizer.events.listen(seen.add);

      _fileIsBack = false;
      normalizer.add('note.md');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(seen.single.kind, WatchEventKind.missing);

      _fileIsBack = true;
      normalizer.add('note.md');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await sub.cancel();

      expect(seen, hasLength(2), reason: 'the return should be reported too');
      expect(seen.last.kind, WatchEventKind.changed);
    });
  });

  group('bursts on different paths do not interfere', () {
    test('each path settles on its own', () async {
      final events = await run(
        <(int, String)>[
          (0, 'a.md'),
          (5, 'b.md'),
          (5, 'a.md'),
          (5, 'c.md'),
          (5, 'b.md'),
        ],
        existsAfter: {'a.md', 'b.md'},
      );

      expect(events.map((e) => e.path).toSet(), {'a.md', 'b.md', 'c.md'});
      expect(
        events.where((e) => e.kind == WatchEventKind.missing).single.path,
        'c.md',
      );
    });
  });

  group('flush, for the window-focus sweep', () {
    test('classifies everything in flight at once', () async {
      final normalizer = WatchNormalizer(
        pathExists: {'a.md'}.contains,
        debounce: const Duration(seconds: 30),
      );
      addTearDown(normalizer.dispose);

      final seen = <WatchEvent>[];
      final sub = normalizer.events.listen(seen.add);

      normalizer
        ..add('a.md')
        ..add('b.md');
      expect(normalizer.hasPending, isTrue);
      expect(seen, isEmpty, reason: 'the 30 s window has not closed');

      normalizer.flush();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(normalizer.hasPending, isFalse);
      expect(seen, hasLength(2));
      expect(
        seen.firstWhere((e) => e.path == 'a.md').kind,
        WatchEventKind.changed,
      );
      expect(
        seen.firstWhere((e) => e.path == 'b.md').kind,
        WatchEventKind.missing,
      );
    });

    test('flushing with nothing pending is harmless', () async {
      final normalizer = WatchNormalizer(pathExists: (_) => true);
      addTearDown(normalizer.dispose);
      expect(normalizer.flush, returnsNormally);
    });
  });

  group('disposal', () {
    test('a settled timer after dispose does not throw', () async {
      final normalizer = WatchNormalizer(
        pathExists: (_) => true,
        debounce: const Duration(milliseconds: 20),
      )..add('note.md');

      await normalizer.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // Reaching here without an exception is the assertion: a watcher that
      // throws on shutdown would take the app with it (CLAUDE.md rule 9).
      expect(normalizer.hasPending, isFalse);
    });
  });
}

/// Flipped by the late-recreation test to model a file coming back.
bool _fileIsBack = false;
