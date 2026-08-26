/// `docs/05_SESSION_AND_SETTINGS.md`: the settings schema, the ranges enforced
/// on load, the migration policy, and CLAUDE.md rule 9 — a settings file
/// someone hand-edited badly must never stop the app opening.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/settings/settings_store.dart';
import 'package:marklens/core/storage/json_store.dart';

void main() {
  late Directory config;
  late SettingsStore store;

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_settings_');
    store = SettingsStore(directory: config);
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  void writeRaw(Object? json) => store.file.writeAsStringSync(jsonEncode(json));

  group('defaults', () {
    test('a first run gets the documented defaults', () {
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.missing);
      expect(loaded.settings.language, AppLanguage.system);
      expect(loaded.settings.theme, AppTheme.system);
      expect(loaded.settings.restoreSession, isTrue);
      expect(loaded.settings.recentLimit, 20);
      expect(loaded.settings.reading.fontScale, 1.0);
      expect(loaded.settings.reading.contentMaxWidth, 760);
      expect(
        loaded.settings.reading.frontMatter,
        FrontMatterDisplay.collapsed,
      );
      expect(loaded.settings.files.fileCap, 1000);
      expect(loaded.settings.files.watchEnabled, isTrue);
      expect(loaded.settings.files.extensions, <String>[
        'md',
        'mdx',
        'markdown',
        'mdown',
        'mkd',
        'mkdn',
        'mdwn',
      ]);
    });

    test('the two network switches default to quiet', () {
      final network = store.load().settings.network;
      expect(
        network.allowRemoteImages,
        isFalse,
        reason: 'zero network by default (CLAUDE.md rule 5)',
      );
      expect(network.updateCheck, isTrue);
    });
  });

  group('round trip', () {
    test('everything survives a save and load', () {
      const settings = AppSettings(
        language: AppLanguage.vi,
        theme: AppTheme.dark,
        restoreSession: false,
        recentLimit: 5,
        reading: ReadingSettings(
          fontScale: 1.5,
          contentMaxWidth: 0,
          frontMatter: FrontMatterDisplay.hidden,
        ),
        files: FilesSettings(
          extensions: <String>['md'],
          fileCap: 250,
          watchEnabled: false,
        ),
        network: NetworkSettings(allowRemoteImages: true, updateCheck: false),
      );

      expect(store.save(settings), isTrue);
      final loaded = store.load().settings;

      expect(loaded.language, AppLanguage.vi);
      expect(loaded.theme, AppTheme.dark);
      expect(loaded.restoreSession, isFalse);
      expect(loaded.recentLimit, 5);
      expect(loaded.reading.fontScale, 1.5);
      expect(loaded.reading.contentMaxWidth, 0);
      expect(loaded.reading.frontMatter, FrontMatterDisplay.hidden);
      expect(loaded.files.extensions, <String>['md']);
      expect(loaded.files.fileCap, 250);
      expect(loaded.files.watchEnabled, isFalse);
      expect(loaded.network.allowRemoteImages, isTrue);
      expect(loaded.network.updateCheck, isFalse);
    });

    test('the written file carries its schema version', () {
      store.save(const AppSettings());
      final json =
          jsonDecode(store.file.readAsStringSync())! as Map<String, Object?>;
      expect(json['version'], AppSettings.schemaVersion);
    });
  });

  group('ranges are enforced on load', () {
    test('fontScale is clamped to 0.5 - 3.0', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'fontScale': 99.0},
      });
      expect(store.load().settings.reading.fontScale, 3.0);

      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'fontScale': 0.01},
      });
      expect(store.load().settings.reading.fontScale, 0.5);
    });

    test('contentMaxWidth is clamped, but zero means full width', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'contentMaxWidth': 5000},
      });
      expect(store.load().settings.reading.contentMaxWidth, 1200);

      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'contentMaxWidth': 0},
      });
      expect(
        store.load().settings.reading.contentMaxWidth,
        0,
        reason: 'zero is a documented value, not a number below the minimum',
      );

      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'contentMaxWidth': 100},
      });
      expect(store.load().settings.reading.contentMaxWidth, 560);
    });

    test('fileCap is clamped to 100 - 2000', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'files': <String, Object?>{'fileCap': 1},
      });
      expect(store.load().settings.files.fileCap, 100);

      writeRaw(<String, Object?>{
        'version': 1,
        'files': <String, Object?>{'fileCap': 999999},
      });
      expect(store.load().settings.files.fileCap, 2000);
    });

    test('recentLimit is bounded so the session file cannot grow forever', () {
      writeRaw(<String, Object?>{'version': 1, 'recentLimit': -5});
      expect(store.load().settings.recentLimit, 0);

      writeRaw(<String, Object?>{'version': 1, 'recentLimit': 100000});
      expect(store.load().settings.recentLimit, AppSettings.maxRecentLimit);
    });

    test('extensions are normalized, and an empty list falls back', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'files': <String, Object?>{
          'extensions': <String>['.MD', 'mdx', 'md'],
        },
      });
      expect(store.load().settings.files.extensions, <String>['md', 'mdx']);

      writeRaw(<String, Object?>{
        'version': 1,
        'files': <String, Object?>{'extensions': <String>[]},
      });
      expect(
        store.load().settings.files.extensions,
        ExtensionsMatcher.defaults,
        reason:
            'an empty list would open nothing at all, which locks the user out '
            'of their own files',
      );
    });
  });

  group('a hand-edited file never stops the app', () {
    test('wrong types fall back field by field', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'language': 42,
        'theme': <String, Object?>{},
        'restoreSession': 'yes',
        'recentLimit': 'lots',
        'reading': 'not an object',
        'files': <String, Object?>{'fileCap': <String>[]},
      });

      final loaded = store.load();
      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(loaded.settings.language, AppLanguage.system);
      expect(loaded.settings.theme, AppTheme.system);
      expect(loaded.settings.restoreSession, isTrue);
      expect(loaded.settings.recentLimit, 20);
      expect(loaded.settings.reading.fontScale, 1.0);
      expect(loaded.settings.files.fileCap, 1000);
    });

    test('an unknown enum value falls back rather than throwing', () {
      writeRaw(<String, Object?>{'version': 1, 'theme': 'solarized'});
      expect(store.load().settings.theme, AppTheme.system);
    });

    test('an integer where a double belongs is accepted', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'reading': <String, Object?>{'fontScale': 2},
      });
      expect(store.load().settings.reading.fontScale, 2.0);
    });

    test('unknown keys are ignored, and dropped on the next write', () {
      writeRaw(<String, Object?>{
        'version': 1,
        'theme': 'dark',
        'somethingFromTheFuture': true,
      });
      final loaded = store.load();
      expect(loaded.settings.theme, AppTheme.dark);

      store.save(loaded.settings);
      final json =
          jsonDecode(store.file.readAsStringSync())! as Map<String, Object?>;
      expect(json.containsKey('somethingFromTheFuture'), isFalse);
    });

    test('a corrupt file starts from defaults and is set aside', () {
      store.file.writeAsStringSync('{ not json');
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.corrupt);
      expect(loaded.settings.theme, AppTheme.system);
      expect(
        config.listSync().where((e) => e.path.contains('corrupt-')),
        hasLength(1),
      );
    });
  });

  group('migration policy', () {
    test('a file with no version is read as v1', () {
      writeRaw(<String, Object?>{'theme': 'dark'});
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.ok);
      expect(
        loaded.settings.theme,
        AppTheme.dark,
        reason: 'v1 is the only shape ever written, so it is the safe reading',
      );
    });

    test('a file from a newer version is backed up, not read', () {
      writeRaw(<String, Object?>{'version': 99, 'theme': 'dark'});
      final loaded = store.load();

      expect(loaded.outcome, JsonLoadOutcome.futureVersion);
      expect(
        loaded.settings.theme,
        AppTheme.system,
        reason:
            'a downgrade must not read a schema it does not know, or it will '
            'quietly rewrite the file and lose whatever was new in it',
      );
      expect(
        config.listSync().where((e) => e.path.contains('bak-')),
        hasLength(1),
        reason: 'the file is kept — the user will want it back on upgrade',
      );
    });
  });
}

/// The default extension list, named so the expectation reads as intent.
abstract final class ExtensionsMatcher {
  static const List<String> defaults = <String>[
    'md',
    'mdx',
    'markdown',
    'mdown',
    'mkd',
    'mkdn',
    'mdwn',
  ];
}
