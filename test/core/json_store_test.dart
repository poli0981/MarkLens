/// `docs/05_SESSION_AND_SETTINGS.md` write discipline, and CLAUDE.md rules 1
/// and 7: the app's only writes go to its own config directory, and they are
/// atomic.
///
/// The last group is the one that earns `lib/core/storage/` its place in the
/// write allowlist of `test/architecture/no_write_test.dart`. That allowlist is
/// a text scan and can only say "this file is allowed to write"; these tests
/// say *where* it writes, which is the rule that actually matters.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/storage/json_store.dart';

void main() {
  late Directory root;
  late Directory config;
  late JsonStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_store_');
    config = Directory(
      '${root.path}${Platform.pathSeparator}config',
    );
    store = JsonStore(directory: config, name: 'settings');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  List<String> namesIn(Directory directory) => directory.existsSync()
      ? (directory
            .listSync()
            .map((e) => e.path.split(RegExp(r'[/\\]')).last)
            .toList()
          ..sort())
      : <String>[];

  group('loading', () {
    test('a missing file is a first run, not a problem', () {
      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.missing);
      expect(loaded.data, isEmpty);
    });

    test('a written file reads back', () {
      store.save(<String, Object?>{'version': 1, 'theme': 'dark'});
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(loaded.data['theme'], 'dark');
    });

    test('nested structures survive the round trip', () {
      final data = <String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'fontScale': 1.25},
        'list': <String>['a', 'b'],
      };
      store.save(data);

      expect(jsonEncode(store.load().data), jsonEncode(data));
    });
  });

  group('corruption keeps the evidence', () {
    test('truncated JSON is set aside and reported', () {
      config.createSync(recursive: true);
      store.file.writeAsStringSync('{"version": 1, "theme": ');

      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.corrupt);
      expect(loaded.data, isEmpty);
      expect(
        store.file.existsSync(),
        isFalse,
        reason: 'the bad file is moved out of the way, not left to fail again',
      );
      expect(
        namesIn(config).where((n) => n.contains('corrupt-')),
        hasLength(1),
        reason:
            'never silently delete the evidence — a corrupt session file is '
            'the only record of what the user had open (docs/05)',
      );
    });

    test('JSON that is not an object is corruption too', () {
      config.createSync(recursive: true);
      store.file.writeAsStringSync('[1, 2, 3]');

      expect(store.load().outcome, JsonLoadOutcome.corrupt);
      expect(
        namesIn(config).where((n) => n.contains('corrupt-')),
        hasLength(1),
      );
    });

    test('an empty file is corruption, and survivable', () {
      config.createSync(recursive: true);
      store.file.writeAsStringSync('');

      expect(store.load().outcome, JsonLoadOutcome.corrupt);
    });

    test('the app recovers on the next run', () {
      config.createSync(recursive: true);
      store.file.writeAsStringSync('not json at all');
      store
        ..load()
        ..save(<String, Object?>{'version': 1, 'theme': 'light'});
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(loaded.data['theme'], 'light');
    });
  });

  group('atomic writes', () {
    test('the config directory is created on first write, not before', () {
      expect(
        config.existsSync(),
        isFalse,
        reason: 'launching the app must touch no disk at all (docs/05)',
      );

      store.save(<String, Object?>{'version': 1});
      expect(config.existsSync(), isTrue);
    });

    test('no temp file is left behind', () {
      store.save(<String, Object?>{'version': 1});
      expect(
        namesIn(config),
        <String>['settings.json'],
        reason: 'the temp file is renamed over the target, never left lying',
      );
    });

    test('a second write replaces the first', () {
      store
        ..save(<String, Object?>{'version': 1, 'n': 1})
        ..save(<String, Object?>{'version': 1, 'n': 2});

      expect(store.load().data['n'], 2);
      expect(namesIn(config), <String>['settings.json']);
    });

    test('the file on disk is readable JSON a person could edit', () {
      store.save(<String, Object?>{'version': 1, 'theme': 'dark'});
      final text = store.file.readAsStringSync();

      expect(
        text,
        contains('\n'),
        reason:
            'doc 05 offers these files as the export path for power users, so '
            'they are written indented rather than on one line',
      );
      expect(jsonDecode(text), isA<Map<String, Object?>>());
    });
  });

  group('quarantine', () {
    test('renames the file out of the way and reports it', () {
      store.save(<String, Object?>{'version': 9});
      expect(store.quarantine('bak'), isTrue);

      expect(store.file.existsSync(), isFalse);
      expect(namesIn(config).where((n) => n.contains('bak-')), hasLength(1));
    });

    test('quarantining nothing is not an error', () {
      expect(store.quarantine('bak'), isFalse);
    });
  });

  group('it writes only inside the directory it was given', () {
    test('a save touches nothing outside it', () {
      final sibling = Directory('${root.path}${Platform.pathSeparator}other')
        ..createSync();
      final marker = File('${sibling.path}${Platform.pathSeparator}keep.txt')
        ..writeAsStringSync('untouched');

      store.save(<String, Object?>{'version': 1});

      expect(namesIn(sibling), <String>['keep.txt']);
      expect(marker.readAsStringSync(), 'untouched');
      expect(
        namesIn(root),
        <String>['config', 'other'],
        reason: 'nothing appeared beside the config directory',
      );
    });

    test('a quarantine stays inside it too', () {
      store
        ..save(<String, Object?>{'version': 1})
        ..quarantine('corrupt');

      expect(namesIn(root), <String>['config']);
      expect(namesIn(config), hasLength(1));
    });

    test('two stores in one directory do not collide', () {
      final session = JsonStore(directory: config, name: 'session');
      store.save(<String, Object?>{'version': 1, 'which': 'settings'});
      session.save(<String, Object?>{'version': 1, 'which': 'session'});

      expect(namesIn(config), <String>['session.json', 'settings.json']);
      expect(store.load().data['which'], 'settings');
      expect(session.load().data['which'], 'session');
    });
  });

  group('failures are reported, never thrown', () {
    test('saving into an impossible directory returns false', () {
      // A file where the directory should be: creating it cannot succeed.
      final blocker = File('${root.path}${Platform.pathSeparator}blocked')
        ..writeAsStringSync('not a directory');
      final blocked = JsonStore(
        directory: Directory(blocker.path),
        name: 'settings',
      );

      expect(blocked.save(<String, Object?>{'version': 1}), isFalse);
    });

    test('loading from an impossible directory is a missing file', () {
      final blocked = JsonStore(
        directory: Directory('${root.path}${Platform.pathSeparator}nope'),
        name: 'settings',
      );
      expect(blocked.load().outcome, JsonLoadOutcome.missing);
    });
  });
}
