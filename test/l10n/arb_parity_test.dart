/// `docs/09_I18N.md` rule 5: "vi/ja may trail within a PR train but must be
/// complete before a release tag".
///
/// `l10n.yaml` already fails the build on a key that exists in `en` and not in
/// the other two — that is what `l10n_untranslated.json` is for. What it cannot
/// see is a key that *is* present because somebody pasted the English in, or a
/// translation that dropped a placeholder and will throw the first time it is
/// formatted. Those are the two ways a locale rots between releases, and this
/// is the file that notices.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys whose value is legitimately the same in every language.
///
/// Each one is here because translating it would be *wrong*, not because
/// nobody got to it — a proper noun, a number, or a filename. Anything else
/// that matches English is an untranslated string.
const Map<String, String> sameInEveryLanguage = <String, String>{
  'appTitle': 'the product name',
  'searchAcrossTruncated': 'a number and a plus sign',
  'statusBarPosition': 'a number and a percent sign',
  'findMatchCounter': 'two numbers and a slash',
  'logExportSuggestedName': 'a filename, and ASCII is what a filename wants',
};

/// Keys the Vietnamese keeps in English as a borrowed technical term.
///
/// Separated from [sameInEveryLanguage] because it is a *translation
/// decision*, not a property of the string: "front matter" is the term
/// Vietnamese technical writing borrows, where the Japanese transliterates it.
/// Listed rather than left to look like an oversight.
const Map<String, String> borrowedInVietnamese = <String, String>{
  'settingsFrontMatter': 'the YAML term, borrowed rather than translated',
  'readerFrontMatterTitle': 'the same term, in the reader',
};

Map<String, String> messages(String locale) {
  final raw = jsonDecode(
    File('lib/l10n/app_$locale.arb').readAsStringSync(),
  );
  final map = raw as Map<String, Object?>;
  return <String, String>{
    for (final entry in map.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value! as String,
  };
}

/// The placeholders `@key` **declares**, from the English ARB.
///
/// Read from the metadata rather than scraped out of the message. A regex over
/// an ICU string cannot tell a placeholder from a plural branch: `=1{1 import
/// hidden}` looks exactly like `{1 …}`, and `other{no matches}` looks exactly
/// like `{no …}`. The metadata is the declaration, so it is the answer.
Map<String, Set<String>> declaredPlaceholders() {
  final raw = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, Object?>;
  final declared = <String, Set<String>>{};
  for (final entry in raw.entries) {
    if (!entry.key.startsWith('@') || entry.value is! Map<String, Object?>) {
      continue;
    }
    final meta = entry.value! as Map<String, Object?>;
    final names = meta['placeholders'];
    if (names is Map<String, Object?> && names.isNotEmpty) {
      declared[entry.key.substring(1)] = names.keys.toSet();
    }
  }
  return declared;
}

/// The top-level keys of an ARB file, in file order, duplicates included.
///
/// Scanned from the text rather than parsed: a JSON parser keeps the last of a
/// duplicate pair, which is precisely the thing being looked for. Nested keys
/// inside an `@`-metadata object are indented further and are not top level.
List<String> topLevelKeys(String locale) => <String>[
  for (final match in RegExp(
    '^  "([^"]+)":',
    multiLine: true,
  ).allMatches(File('lib/l10n/app_$locale.arb').readAsStringSync()))
    match.group(1)!,
];

void main() {
  final en = messages('en');
  final locales = <String, Map<String, String>>{
    'vi': messages('vi'),
    'ja': messages('ja'),
  };

  group('the corpus itself', () {
    test('en has strings, so the rest of this file means something', () {
      expect(en, isNotEmpty);
      expect(en.length, greaterThan(100));
    });

    test('no key is defined twice in any locale', () {
      // JSON parsers keep the last of a duplicate pair, so a copy-pasted block
      // silently wins and the earlier value disappears. It happened once
      // during M3, to `sidebarPin`.
      for (final locale in <String>['en', 'vi', 'ja']) {
        final seen = <String>{};
        final duplicates = <String>[
          for (final key in topLevelKeys(locale))
            if (!seen.add(key)) key,
        ];

        expect(duplicates, isEmpty, reason: '$locale defines these twice');
      }
    });
  });

  group('completeness', () {
    for (final locale in <String>['vi', 'ja']) {
      test('$locale defines every key en does', () {
        final missing = en.keys.where((k) => !locales[locale]!.containsKey(k));

        expect(
          missing,
          isEmpty,
          reason:
              'release-blocking (docs/09 rule 5); see '
              'l10n_untranslated.json',
        );
      });

      test('$locale defines nothing en does not', () {
        // A key removed from en and left behind elsewhere is dead weight that
        // reads as a translation somebody owes.
        final extra = locales[locale]!.keys.where((k) => !en.containsKey(k));

        expect(extra, isEmpty, reason: '$locale has orphans');
      });
    }
  });

  group('actually translated', () {
    for (final locale in <String>['vi', 'ja']) {
      test('$locale is not English wearing a different filename', () {
        final untranslated = <String>[
          for (final entry in locales[locale]!.entries)
            if (en[entry.key] == entry.value &&
                !sameInEveryLanguage.containsKey(entry.key) &&
                !(locale == 'vi' &&
                    borrowedInVietnamese.containsKey(entry.key)))
              entry.key,
        ];

        expect(
          untranslated,
          isEmpty,
          reason:
              'these match the English exactly. If that is deliberate, add '
              'them to sameInEveryLanguage or borrowedInVietnamese with the '
              'reason — the point is that it be a decision.',
        );
      });
    }

    test('and the allowlists have not gone stale', () {
      for (final key in <String>[
        ...sameInEveryLanguage.keys,
        ...borrowedInVietnamese.keys,
      ]) {
        expect(
          en.containsKey(key),
          isTrue,
          reason: '$key is allowlisted and no longer exists',
        );
      }
    });
  });

  group('placeholders survive translation', () {
    final declared = declaredPlaceholders();

    test('there are some to check', () {
      expect(declared, isNotEmpty);
    });

    for (final locale in <String>['vi', 'ja']) {
      test('$locale keeps every one', () {
        // A translation that drops `{count}` does not fail to load — it throws
        // the first time somebody opens the screen that formats it, in the one
        // locale nobody on the team reads.
        final broken = <String>[];
        for (final entry in declared.entries) {
          final translated = locales[locale]![entry.key];
          if (translated == null) {
            continue;
          }
          for (final name in entry.value) {
            if (!translated.contains('{$name}') &&
                !translated.contains('{$name,')) {
              broken.add('${entry.key} lost {$name}');
            }
          }
        }

        expect(broken, isEmpty, reason: '$locale lost a placeholder');
      });
    }
  });

  group('accelerators', () {
    // Doc 06: `Alt+F` / `Alt+V` / `Alt+H` work "through accelerator labels
    // carried in the translated strings", because the letter has to differ per
    // language. A title with no marker has no accelerator at all, and one with
    // two has an ambiguous one.
    const titles = <String>['menuFile', 'menuView', 'menuHelp'];

    for (final locale in <String>['en', 'vi', 'ja']) {
      test('$locale marks exactly one letter per menu title', () {
        final strings = locale == 'en' ? en : locales[locale]!;
        for (final key in titles) {
          expect(
            '&'.allMatches(strings[key]!).length,
            1,
            reason: '$locale $key is "${strings[key]}"',
          );
        }
      });

      test('$locale gives the three menus three different accelerators', () {
        final strings = locale == 'en' ? en : locales[locale]!;
        final letters = <String>{
          for (final key in titles)
            strings[key]![strings[key]!.indexOf('&') + 1].toUpperCase(),
        };

        expect(
          letters,
          hasLength(3),
          reason: 'two menus sharing Alt+X means one of them is unreachable',
        );
      });
    }
  });
}
