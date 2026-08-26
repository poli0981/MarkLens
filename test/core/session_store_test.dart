/// `docs/05_SESSION_AND_SETTINGS.md` (session schema, migration, write
/// discipline) and CLAUDE.md rule 7: persistence writes are debounced and
/// atomic, never one write per scroll tick.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/core/storage/json_store.dart';

void main() {
  late Directory config;
  late SessionStore store;

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_session_');
    store = SessionStore(
      directory: config,
      debounce: const Duration(milliseconds: 40),
    );
  });

  tearDown(() {
    store.dispose();
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  void writeRaw(Object? json) => store.file.writeAsStringSync(jsonEncode(json));

  group('defaults', () {
    test('a first run is an empty session', () {
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.missing);
      expect(loaded.state.documents, isEmpty);
      expect(loaded.state.openRoots, isEmpty);
      expect(loaded.state.recent, isEmpty);
      expect(loaded.state.activePath, isNull);
      expect(loaded.state.window, isNull);
      expect(loaded.state.sidebarWidth, 280);
      expect(loaded.state.outlineVisible, isTrue);
    });
  });

  group('round trip', () {
    test('everything survives a save and load', () {
      const state = SessionState(
        window: WindowGeometry(x: 120, y: 80, width: 1280, height: 800),
        sidebarWidth: 320,
        outlineVisible: false,
        openRoots: <String>['/dev/docs'],
        documents: <SessionDocument>[
          SessionDocument(
            path: '/dev/docs/README.md',
            scroll: 0.42,
            pinned: true,
          ),
          SessionDocument(path: '/dev/docs/other.md'),
        ],
        activePath: '/dev/docs/README.md',
        recent: <String>['/notes/todo.md'],
      );

      store.save(state);
      expect(store.flush(), isTrue);

      final loaded = store.load().state;
      expect(loaded.window!.width, 1280);
      expect(loaded.window!.maximized, isFalse);
      expect(loaded.sidebarWidth, 320);
      expect(loaded.outlineVisible, isFalse);
      expect(loaded.openRoots, <String>['/dev/docs']);
      expect(loaded.documents, hasLength(2));
      expect(loaded.documents.first.scroll, 0.42);
      expect(loaded.documents.first.pinned, isTrue);
      expect(loaded.activePath, '/dev/docs/README.md');
      expect(loaded.recent, <String>['/notes/todo.md']);
    });

    test('the written file carries its schema version', () {
      store
        ..save(SessionState.empty)
        ..flush();

      final json =
          jsonDecode(store.file.readAsStringSync())! as Map<String, Object?>;
      expect(json['version'], SessionState.schemaVersion);
    });
  });

  group('writes are debounced (rule 7)', () {
    test('saving does not write immediately', () {
      store.save(SessionState.empty);

      expect(
        store.file.existsSync(),
        isFalse,
        reason:
            'a save on every scroll tick must not be a write on every scroll '
            'tick — that is the whole point of rule 7',
      );
      expect(store.hasPending, isTrue);
    });

    test('a burst of saves becomes one write', () async {
      for (var i = 0; i < 50; i++) {
        store.save(
          SessionState(
            documents: <SessionDocument>[
              SessionDocument(path: '/a.md', scroll: i / 100),
            ],
          ),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(store.file.existsSync(), isTrue);
      expect(
        store.load().state.documents.single.scroll,
        0.49,
        reason: 'the last state in the window is the one that reaches disk',
      );
    });

    test('the timer eventually writes without a flush', () async {
      store.save(
        const SessionState(openRoots: <String>['/only-from-the-timer']),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(store.load().state.openRoots, <String>['/only-from-the-timer']);
      expect(store.hasPending, isFalse);
    });

    test('flush writes now and clears the pending state', () {
      store.save(const SessionState(openRoots: <String>['/now']));

      expect(store.flush(), isTrue);
      expect(store.hasPending, isFalse);
      expect(store.load().state.openRoots, <String>['/now']);
    });

    test('flushing with nothing pending is harmless', () {
      expect(store.flush(), isFalse);
      expect(store.file.existsSync(), isFalse);
    });

    test('dispose writes what was pending', () {
      store
        ..save(const SessionState(openRoots: <String>['/quitting']))
        ..dispose();

      expect(
        store.load().state.openRoots,
        <String>['/quitting'],
        reason: 'quitting must not lose the last second of a session',
      );
    });

    test('saving after dispose does nothing', () {
      store
        ..dispose()
        ..save(const SessionState(openRoots: <String>['/too-late']));

      expect(store.hasPending, isFalse);
      expect(store.flush(), isFalse);
    });
  });

  group('a hand-edited file never stops the app', () {
    test('an entry with no path is dropped, the rest restore', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'files': <Object?>[
          <String, Object?>{'path': '/good.md'},
          <String, Object?>{'scroll': 0.5},
          'not an object',
          <String, Object?>{'path': '   '},
        ],
      });

      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(
        loaded.state.documents.map((d) => d.path),
        <String>['/good.md'],
        reason: 'losing one tab beats losing the session',
      );
    });

    test('scroll is clamped into 0..1', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'files': <Object?>[
          <String, Object?>{'path': '/a.md', 'scroll': 5},
          <String, Object?>{'path': '/b.md', 'scroll': -2},
        ],
      });

      final documents = store.load().state.documents;
      expect(documents[0].scroll, 1.0);
      expect(documents[1].scroll, 0.0);
    });

    test('an active path outside the open set is discarded', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'files': <Object?>[
          <String, Object?>{'path': '/a.md'},
        ],
        'activePath': '/not-open.md',
      });

      expect(
        store.load().state.activePath,
        isNull,
        reason: 'the reader would otherwise be pointed at nothing',
      );
    });

    test('an unusable window geometry is dropped, not repaired', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'window': <String, Object?>{'x': 0, 'y': 0, 'w': 1, 'h': 1},
      });
      expect(
        store.load().state.window,
        isNull,
        reason:
            'opening at the default size beats opening one pixel tall, or on '
            'a monitor that is no longer attached',
      );

      writeRaw(<String, Object?>{
        'version': 1,
        'window': <String, Object?>{'x': 0, 'y': 0},
      });
      expect(store.load().state.window, isNull);
    });

    test('the sidebar width is clamped into something usable', () {
      writeRaw(<String, Object?>{'version': 1, 'sidebarWidth': 5});
      expect(store.load().state.sidebarWidth, SessionState.minSidebarWidth);

      writeRaw(<String, Object?>{'version': 1, 'sidebarWidth': 99999});
      expect(store.load().state.sidebarWidth, SessionState.maxSidebarWidth);
    });

    test('duplicate roots and recents are deduped, order kept', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'openRoots': <String>['/a', '/b', '/a'],
        'recent': <Object?>['/x', '/x', 42, '', '/y'],
      });

      final state = store.load().state;
      expect(state.openRoots, <String>['/a', '/b']);
      expect(state.recent, <String>['/x', '/y']);
    });

    test('a corrupt file starts an empty session and is set aside', () {
      writeRaw(<String, Object?>{'version': 1});
      store.file.writeAsStringSync('{ truncated');

      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.corrupt);
      expect(loaded.state.documents, isEmpty);
      expect(
        config.listSync().where((e) => e.path.contains('corrupt-')),
        hasLength(1),
      );
    });
  });

  group('migration policy', () {
    test('a file with no version is read as v1', () {
      writeRaw(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'path': '/a.md'},
        ],
      });

      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(loaded.state.documents, hasLength(1));
    });

    test('a file from a newer version is backed up, not read', () {
      writeRaw(<String, Object?>{
        'version': 99,
        'files': <Object?>[
          <String, Object?>{'path': '/a.md'},
        ],
      });

      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.futureVersion);
      expect(loaded.state.documents, isEmpty);
      expect(
        config.listSync().where((e) => e.path.contains('bak-')),
        hasLength(1),
      );
    });
  });
}
