/// `WatchService`: which directories get a watcher, and what reaches the
/// normalizer (`docs/07_FILES_AND_WATCH.md`, spike S5).
///
/// No real filesystem and no real watcher: the factory is injected, so these
/// assert the *decisions* — one watcher per root, ad-hoc files watched through
/// their parent, nested roots not doubled, temp files filtered — without
/// sleeping. The real-filesystem observations live behind the `watcher-live`
/// tag in `test/platform/`.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/watch/watch_service.dart';
import 'package:watcher/watcher.dart' as w;

/// A watcher that emits whatever a test pushes into it.
class _FakeWatcher implements w.DirectoryWatcher {
  _FakeWatcher(this.path);

  @override
  final String path;

  final StreamController<w.WatchEvent> controller =
      StreamController<w.WatchEvent>.broadcast();

  @override
  Stream<w.WatchEvent> get events => controller.stream;

  @override
  Future<void> get ready async {}

  @override
  String get directory => path;

  @override
  bool get isReady => true;
}

void main() {
  late Map<String, _FakeWatcher> opened;
  late Set<String> existing;
  late WatchService service;

  const separator = r'\';
  String at(String path) => 'C:${separator}docs$separator$path';

  setUp(() {
    opened = <String, _FakeWatcher>{};
    existing = <String>{};
    service = WatchService(
      pathExists: existing.contains,
      openWatcher: (path) => opened[path] = _FakeWatcher(path),
      debounce: const Duration(milliseconds: 10),
    );
  });

  tearDown(() async => service.dispose());

  group('which directories get a watcher', () {
    test('one per open root', () {
      service.watch(
        roots: <String>[r'C:\a', r'C:\b'],
        files: const <String>[],
      );
      expect(opened.keys, unorderedEquals(<String>[r'C:\a', r'C:\b']));
    });

    test('an ad-hoc file is watched through its parent directory', () {
      service.watch(roots: const <String>[], files: <String>[at('note.md')]);

      expect(
        opened.keys,
        <String>[r'C:\docs'],
        reason:
            'never FileWatcher: on Windows the package silently polls at '
            '1000 ms, against 7 ms through the parent (spike S5)',
      );
      expect(
        opened.keys.any((path) => path.endsWith('.md')),
        isFalse,
        reason: 'the factory must never be handed a file path',
      );
    });

    test('two ad-hoc files in one directory share its watcher', () {
      service.watch(
        roots: const <String>[],
        files: <String>[at('a.md'), at('b.md')],
      );
      expect(opened.keys, hasLength(1));
    });

    test('a directory already inside a watched root is not watched twice', () {
      service.watch(
        roots: <String>[r'C:\docs'],
        files: <String>[at('guide${separator}intro.md')],
      );
      expect(
        opened.keys,
        <String>[r'C:\docs'],
        reason: 'DirectoryWatcher is recursive, so a nested one doubles events',
      );
    });

    test('nesting is judged the same way whichever separator wrote it', () {
      // This is the one that only failed on Linux: the check used to key on
      // `Platform.pathSeparator`, so a Windows-style root restored from a
      // session written on the other OS quietly got two watchers.
      for (final paths in <(String, String)>[
        (r'C:\docs', r'C:\docs\guide\intro.md'),
        ('/home/kokone/docs', '/home/kokone/docs/guide/intro.md'),
      ]) {
        final service = WatchService(
          pathExists: (_) => true,
          openWatcher: _FakeWatcher.new,
        )..watch(roots: <String>[paths.$1], files: <String>[paths.$2]);
        addTearDown(service.dispose);

        expect(
          service.watchedDirectories,
          <String>[paths.$1],
          reason: '${paths.$2} is already inside ${paths.$1}',
        );
      }
    });

    test('a sibling directory with a shared prefix is not "inside"', () {
      expect(
        WatchService.isInsideDirectory(r'C:\docs2\note.md', r'C:\docs'),
        isFalse,
        reason: 'without the trailing separator, docs2 counts as inside docs',
      );
      expect(
        WatchService.isInsideDirectory(r'C:\docs\note.md', r'C:\docs'),
        isTrue,
      );
    });

    test('calling watch again with the same set changes nothing', () {
      service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);
      final first = opened[r'C:\docs'];
      service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);

      expect(
        identical(opened[r'C:\docs'], first),
        isTrue,
        reason: 'the open set changes constantly; re-syncing must be free',
      );
    });

    test('a root that is no longer open stops being watched', () {
      service
        ..watch(roots: <String>[r'C:\a', r'C:\b'], files: const <String>[])
        ..watch(roots: <String>[r'C:\a'], files: const <String>[]);

      expect(service.watchedDirectories, <String>[r'C:\a']);
    });
  });

  group('what reaches the normalizer', () {
    Future<List<WatchEvent>> collect(Future<void> Function() body) async {
      final events = <WatchEvent>[];
      final subscription = service.events.listen(events.add);
      await body();
      await subscription.cancel();
      return events;
    }

    test('a save becomes one changed event', () async {
      existing.add(at('note.md'));
      service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);

      final events = await collect(() async {
        opened[r'C:\docs']!.controller.add(
          w.WatchEvent(w.ChangeType.MODIFY, at('note.md')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });

      expect(events, hasLength(1));
      expect(events.single.kind, WatchEventKind.changed);
      expect(events.single.path, at('note.md'));
    });

    test('the editor temp and backup files are filtered out', () async {
      service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);

      final events = await collect(() async {
        final watcher = opened[r'C:\docs']!.controller;
        for (final name in <String>['note.md.tmp', 'note.md~', 'note.swp']) {
          watcher.add(w.WatchEvent(w.ChangeType.ADD, at(name)));
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });

      expect(
        events,
        isEmpty,
        reason: 'S5 measured Linux reporting all of these beside a real save',
      );
    });

    test('a deletion becomes missing, classified by existence', () async {
      service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);

      final events = await collect(() async {
        opened[r'C:\docs']!.controller.add(
          // The kind says REMOVE, but the kind is not what decides — the first
          // event of an atomic save says REMOVE too (S5).
          w.WatchEvent(w.ChangeType.REMOVE, at('gone.md')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });

      expect(events.single.kind, WatchEventKind.missing);
    });

    test(
      'a delete-then-recreate is one changed, not a missing flash',
      () async {
        service.watch(roots: <String>[r'C:\docs'], files: const <String>[]);

        final events = await collect(() async {
          final watcher = opened[r'C:\docs']!.controller
            ..add(w.WatchEvent(w.ChangeType.REMOVE, at('note.md')));
          await Future<void>.delayed(const Duration(milliseconds: 5));
          existing.add(at('note.md'));
          watcher.add(w.WatchEvent(w.ChangeType.ADD, at('note.md')));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });

        expect(events, hasLength(1));
        expect(
          events.single.kind,
          WatchEventKind.changed,
          reason: 'no false missing badge may flash during an atomic save',
        );
      },
    );
  });

  group('failure degrades rather than throwing', () {
    test('a watcher that cannot start leaves the others running', () {
      final failing = WatchService(
        pathExists: (_) => true,
        openWatcher: (path) {
          if (path.endsWith('bad')) {
            throw StateError('cannot watch');
          }
          return _FakeWatcher(path);
        },
      );
      addTearDown(failing.dispose);

      failing.watch(
        roots: <String>[r'C:\good', r'C:\bad'],
        files: const <String>[],
      );

      expect(
        failing.degraded,
        isTrue,
        reason:
            'the caller falls back to the '
            'focus sweep (doc 07), and never sees an error',
      );
      expect(failing.watchedDirectories, <String>[r'C:\good']);
    });
  });

  group('parentOf', () {
    test('handles both separators, whichever platform wrote the path', () {
      expect(WatchService.parentOf(r'C:\docs\note.md'), r'C:\docs');
      expect(
        WatchService.parentOf('/home/kokone/docs/note.md'),
        '/home/kokone/docs',
      );
    });

    test('keeps the separator on a root', () {
      expect(WatchService.parentOf(r'C:\note.md'), r'C:\');
      expect(WatchService.parentOf('/note.md'), '/');
    });

    test('a bare name has no parent', () {
      expect(WatchService.parentOf('note.md'), '');
    });
  });
}
