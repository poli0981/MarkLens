/// `docs/03_DATA_FLOW.md` (the open set, dedupe by canonical path) and
/// `docs/06_UI_UX.md` (pinning, MRU cycling, reopen).
///
/// The sidebar and the tab strip are two views of this one state, so the
/// behaviour is asserted here once rather than twice through widgets.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/file_service.dart';

void main() {
  late Directory root;
  late ProviderContainer container;

  String at(String relative) =>
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}';

  void writeFile(String relative, [String content = '# Doc']) {
    final file = File(at(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  // A function, not a getter: a getter cannot be declared inside main().
  OpenSetController controller() => container.read(openSetProvider.notifier);

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_openset_');
    writeFile('a.md');
    writeFile('b.md');
    writeFile('c.md');
    container = ProviderContainer(
      overrides: [configDirectoryProvider.overrideWithValue(root)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  String identityOf(String relative) =>
      const FileService().describe(at(relative))!.identity;

  group('opening', () {
    test('appends and activates the first', () {
      expect(controller().openPaths(<String>[at('a.md'), at('b.md')]), 2);

      final set = container.read(openSetProvider);
      expect(set.entries.map((e) => e.file.name), <String>['a.md', 'b.md']);
      expect(set.active!.file.name, 'a.md');
    });

    test('a second open of the same file does not duplicate it', () {
      controller()
        ..openPaths(<String>[at('a.md')])
        ..openPaths(<String>[at('a.md')]);

      expect(container.read(openSetProvider).entries, hasLength(1));
    });

    test('a path that is not a file resolves to nothing', () {
      expect(controller().openPaths(<String>[at('missing.md')]), 0);
      expect(container.read(openSetProvider).entries, isEmpty);
    });

    test('a mix reports only what resolved', () {
      expect(controller().openPaths(<String>[at('a.md'), at('missing.md')]), 1);
    });

    test('opening without activating leaves the active document alone', () {
      controller()
        ..openPaths(<String>[at('a.md')])
        ..openPaths(<String>[at('b.md')], activate: false);

      expect(container.read(openSetProvider).active!.file.name, 'a.md');
    });
  });

  group('folders', () {
    test('a scan under the cap opens everything and records the root', () {
      controller().openFolder(root.path);

      final set = container.read(openSetProvider);
      expect(set.entries, hasLength(3));
      expect(set.roots, <String>[root.path]);
      expect(set.capExceededRoot, isNull);
    });

    test('a scan over the cap opens nothing and asks first', () {
      final capped = ProviderContainer(
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          fileServiceProvider.overrideWithValue(const FileService(fileCap: 2)),
        ],
      );
      addTearDown(capped.dispose);

      capped.read(openSetProvider.notifier).openFolder(root.path);

      expect(
        capped.read(openSetProvider).entries,
        isEmpty,
        reason:
            'doc 07: never silently truncate — the user is asked "Open first '
            'N / Cancel" before anything opens',
      );
      expect(capped.read(openSetProvider).capExceededRoot, root.path);

      capped.read(openSetProvider.notifier).acceptCappedScan();
      expect(capped.read(openSetProvider).entries, hasLength(2));
      expect(capped.read(openSetProvider).capExceededRoot, isNull);
    });

    test('cancelling the cap question opens nothing', () {
      final capped = ProviderContainer(
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          fileServiceProvider.overrideWithValue(const FileService(fileCap: 2)),
        ],
      );
      addTearDown(capped.dispose);

      capped.read(openSetProvider.notifier)
        ..openFolder(root.path)
        ..cancelCappedScan();

      expect(capped.read(openSetProvider).entries, isEmpty);
      expect(capped.read(openSetProvider).capExceededRoot, isNull);
    });
  });

  group('closing and reopening', () {
    setUp(() {
      controller().openPaths(<String>[at('a.md'), at('b.md'), at('c.md')]);
    });

    test('closing the active one lands on the most recent survivor', () {
      controller()
        ..activate(identityOf('b.md'))
        ..activate(identityOf('c.md'))
        ..close(identityOf('c.md'));

      expect(
        container.read(openSetProvider).active!.file.name,
        'b.md',
        reason:
            'closing a tab should land where the reader was, not somewhere '
            'arbitrary',
      );
    });

    test('closing an inactive one leaves the active alone', () {
      controller().close(identityOf('c.md'));
      expect(container.read(openSetProvider).active!.file.name, 'a.md');
    });

    test('closing the last one leaves nothing active', () {
      for (final name in <String>['a.md', 'b.md', 'c.md']) {
        controller().close(identityOf(name));
      }
      expect(container.read(openSetProvider).active, isNull);
      expect(container.read(openSetProvider).isEmpty, isTrue);
    });

    test('reopen brings back the most recently closed', () {
      controller()
        ..close(identityOf('b.md'))
        ..close(identityOf('c.md'))
        ..reopenClosed();

      expect(container.read(openSetProvider).active!.file.name, 'c.md');
      controller().reopenClosed();
      expect(
        container.read(openSetProvider).entries.map((e) => e.file.name),
        containsAll(<String>['a.md', 'b.md', 'c.md']),
      );
    });

    test('reopening with nothing closed is harmless', () {
      controller().reopenClosed();
      expect(container.read(openSetProvider).entries, hasLength(3));
    });

    test('close all keeps the reopen history', () {
      controller().closeAll();
      expect(container.read(openSetProvider).isEmpty, isTrue);

      controller().reopenClosed();
      expect(container.read(openSetProvider).entries, hasLength(1));
    });
  });

  group('cycling is MRU, not strip order', () {
    setUp(() {
      controller().openPaths(<String>[at('a.md'), at('b.md'), at('c.md')]);
    });

    test('forward walks the most recently used', () {
      controller()
        ..activate(identityOf('a.md'))
        ..activate(identityOf('c.md'))
        ..activate(identityOf('b.md'));

      // MRU is now b, c, a.
      controller().cycle(1);
      expect(container.read(openSetProvider).active!.file.name, 'c.md');
    });

    test('backward wraps', () {
      controller()
        ..activate(identityOf('a.md'))
        ..cycle(-1);
      expect(container.read(openSetProvider).active, isNotNull);
    });

    test('cycling one document is a no-op', () {
      controller()
        ..closeAll()
        ..openPaths(<String>[at('a.md')])
        ..cycle(1);
      expect(container.read(openSetProvider).active!.file.name, 'a.md');
    });
  });

  group('pinning and scroll', () {
    test('pin toggles without reordering the entries', () {
      controller()
        ..openPaths(<String>[at('a.md'), at('b.md')])
        ..togglePin(identityOf('b.md'));

      final set = container.read(openSetProvider);
      expect(set.entries.map((e) => e.file.name), <String>['a.md', 'b.md']);
      expect(set.entryFor(identityOf('b.md'))!.pinned, isTrue);

      controller().togglePin(identityOf('b.md'));
      expect(
        container.read(openSetProvider).entryFor(identityOf('b.md'))!.pinned,
        isFalse,
      );
    });

    test('scroll is recorded for the session', () {
      controller()
        ..openPaths(<String>[at('a.md')])
        ..recordScroll(identityOf('a.md'), 0.42);
      expect(
        container.read(openSetProvider).entries.single.scroll,
        0.42,
      );
    });
  });

  group('refreshing from disk', () {
    test('a vanished file keeps its entry and gains the badge', () {
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      File(at('b.md')).deleteSync();

      controller().refreshAll();

      final entry = container
          .read(openSetProvider)
          .entries
          .firstWhere((e) => e.file.name == 'b.md');
      expect(entry.file.missing, isTrue);
      expect(container.read(openSetProvider).entries, hasLength(2));
    });

    test('a background change marks the tab stale, the active one not', () {
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      writeFile('a.md', '# Changed and longer than before');
      writeFile('b.md', '# Also changed and longer than before');

      controller().refreshAll();

      final set = container.read(openSetProvider);
      expect(
        set.entryFor(identityOf('a.md'))!.stale,
        isFalse,
        reason: 'the active document is re-parsed, not dotted',
      );
      expect(
        set.entryFor(identityOf('b.md'))!.stale,
        isTrue,
        reason: 'the dot is what says "this changed while you were elsewhere"',
      );
    });

    test('activating a stale tab clears the dot', () {
      controller().openPaths(<String>[at('a.md'), at('b.md')]);
      writeFile('b.md', '# Changed and longer than before');
      controller()
        ..refreshAll()
        ..activate(identityOf('b.md'));

      expect(
        container.read(openSetProvider).entryFor(identityOf('b.md'))!.stale,
        isFalse,
      );
    });
  });

  group('restoring a session', () {
    test('keeps order, pins and scroll', () {
      controller().restore(
        documents: <({String path, double scroll, bool pinned})>[
          (path: at('b.md'), scroll: 0.5, pinned: true),
          (path: at('a.md'), scroll: 0, pinned: false),
        ],
        roots: <String>[root.path],
        activePath: at('a.md'),
      );

      final set = container.read(openSetProvider);
      expect(set.entries.map((e) => e.file.name), <String>['b.md', 'a.md']);
      expect(set.entries.first.pinned, isTrue);
      expect(set.entries.first.scroll, 0.5);
      expect(set.active!.file.name, 'a.md');
      expect(set.roots, <String>[root.path]);
    });

    test('a file that has gone is kept and badged, not pruned', () {
      controller().restore(
        documents: <({String path, double scroll, bool pinned})>[
          (path: at('gone.md'), scroll: 0, pinned: false),
        ],
        roots: const <String>[],
      );

      final entry = container.read(openSetProvider).entries.single;
      expect(entry.file.missing, isTrue);
      expect(entry.file.name, 'gone.md');
    });

    test('an active path that is not in the set falls back to the first', () {
      controller().restore(
        documents: <({String path, double scroll, bool pinned})>[
          (path: at('a.md'), scroll: 0, pinned: false),
        ],
        roots: const <String>[],
        activePath: at('somewhere-else.md'),
      );

      expect(container.read(openSetProvider).active!.file.name, 'a.md');
    });

    test('an empty session restores to nothing', () {
      controller().restore(
        documents: const <({String path, double scroll, bool pinned})>[],
        roots: const <String>[],
      );
      expect(container.read(openSetProvider).isEmpty, isTrue);
      expect(container.read(openSetProvider).active, isNull);
    });
  });
}
