/// `copyWith` on the settings tree (`docs/05_SESSION_AND_SETTINGS.md`).
///
/// The ranges doc 05 defines used to be enforced in `fromJson` only, because
/// nothing could change a setting at runtime. Now that the View menu and the
/// zoom shortcuts can, `copyWith` has to hold the same bounds — otherwise a
/// held `Ctrl+=` walks `fontScale` past 3.0, writes it, and the next load
/// silently pulls it back to a number the user never chose.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/models/app_settings.dart';

void main() {
  group('copyWith leaves everything it was not given alone', () {
    test('at the top level', () {
      const before = AppSettings();
      final after = before.copyWith(theme: ThemePreference.dark);

      expect(after.theme, ThemePreference.dark);
      expect(after.language, before.language);
      expect(after.restoreSession, before.restoreSession);
      expect(after.recentLimit, before.recentLimit);
      expect(
        after.reading,
        same(before.reading),
        reason:
            'an untouched sub-object comes back as the same instance, which is '
            'what lets settingsProvider.select skip an unrelated rebuild',
      );
      expect(after.files, same(before.files));
      expect(after.network, same(before.network));
    });

    test('inside reading settings', () {
      const before = ReadingSettings();
      final after = before.copyWith(fontScale: 1.4);

      expect(after.fontScale, closeTo(1.4, 1e-9));
      expect(after.contentMaxWidth, before.contentMaxWidth);
      expect(after.frontMatter, before.frontMatter);
    });
  });

  group('copyWith clamps exactly where fromJson clamps', () {
    test('font scale cannot escape its bounds', () {
      const reading = ReadingSettings();
      expect(reading.copyWith(fontScale: 99).fontScale, 3.0);
      expect(reading.copyWith(fontScale: 0.01).fontScale, 0.5);
      expect(reading.copyWith(fontScale: -5).fontScale, 0.5);
    });

    test('content width clamps, but zero stays zero', () {
      const reading = ReadingSettings();
      expect(reading.copyWith(contentMaxWidth: 10).contentMaxWidth, 560);
      expect(reading.copyWith(contentMaxWidth: 9000).contentMaxWidth, 1200);
      expect(
        reading.copyWith(contentMaxWidth: 0).contentMaxWidth,
        0,
        reason: 'zero is full width, not a number below the minimum (doc 05)',
      );
    });

    test('the file cap clamps', () {
      const files = FilesSettings();
      expect(files.copyWith(fileCap: 1).fileCap, 100);
      expect(files.copyWith(fileCap: 99999).fileCap, 2000);
    });

    test(
      'an emptied extension list falls back rather than opening nothing',
      () {
        const files = FilesSettings();
        expect(
          files.copyWith(extensions: const <String>[]).extensions,
          files.extensions,
          reason:
              'an empty registry would lock the user out of their own files',
        );
      },
    );

    test('the recent limit clamps', () {
      const settings = AppSettings();
      expect(settings.copyWith(recentLimit: -3).recentLimit, 0);
      expect(
        settings.copyWith(recentLimit: 10000).recentLimit,
        AppSettings.maxRecentLimit,
      );
    });
  });

  group('a copied object round-trips through JSON unchanged', () {
    test('every field survives', () {
      const before = AppSettings();
      final after = before.copyWith(
        theme: ThemePreference.dark,
        language: AppLanguage.ja,
        reading: const ReadingSettings().copyWith(
          fontScale: 1.3,
          contentMaxWidth: 0,
          frontMatter: FrontMatterDisplay.hidden,
        ),
        files: const FilesSettings().copyWith(
          watchEnabled: false,
          fileCap: 250,
        ),
        network: const NetworkSettings().copyWith(updateCheck: false),
      );

      final reloaded = AppSettings.fromJson(after.toJson());

      expect(reloaded.theme, ThemePreference.dark);
      expect(reloaded.language, AppLanguage.ja);
      expect(reloaded.reading.fontScale, closeTo(1.3, 1e-9));
      expect(reloaded.reading.contentMaxWidth, 0);
      expect(reloaded.reading.frontMatter, FrontMatterDisplay.hidden);
      expect(reloaded.files.watchEnabled, isFalse);
      expect(reloaded.files.fileCap, 250);
      expect(reloaded.network.updateCheck, isFalse);
    });
  });
}
