/// No feature names a font family in a string literal.
///
/// `fontFamily: 'monospace'` with a `['Courier New', 'monospace']` fallback
/// existed in three files — `reader_style.dart`, `code_block_builder.dart` and
/// `front_matter_panel.dart` — byte-identical in all three, because each was
/// written by copying the last. Nothing made them change together, and when the
/// bundled fonts landed at M4 all three had to.
///
/// The rule is not "do not repeat yourself". It is that a family name in
/// `features/` is a *typography decision made in the wrong layer*: doc 02 puts
/// the theme in `app/`, and the renderer seam exists so that swapping renderers
/// cannot quietly change the app's typography
/// (`lib/features/reader/rendering/markdown_renderer.dart` says so in its own
/// doc comment). A literal in a feature is exactly that change, made by
/// accident.
///
/// Same token-scanning shape as `no_write_test.dart`, and the same trade-off:
/// whole-line comments are stripped, trailing ones are not, so a false positive
/// is possible and a false negative is not.
library;

import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// Family names that must not appear as literals under `lib/features/`.
///
/// Deliberately short. This is not a list of every font in existence — it is
/// the three the app actually names plus the two the old literals used, which
/// is what a copy-paste would reintroduce.
const List<String> fontFamilyLiterals = <String>[
  "'monospace'",
  "'Courier New'",
  "'Noto Sans'",
  "'Noto Sans JP'",
  "'JetBrains Mono'",
];

void main() {
  test('no feature hard-codes a font family', () {
    final sources = dartSourcesUnder('lib/features');
    expect(
      sources,
      isNotEmpty,
      reason: 'lib/features is empty, so this test proves nothing.',
    );

    final offenders = <String, List<String>>{};
    for (final source in sources) {
      final found = forbiddenTokensIn(source.code, fontFamilyLiterals);
      if (found.isNotEmpty) {
        offenders[source.path] = found;
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A font family is named in a feature: $offenders. The families live '
          'in lib/app/theme/typography.dart and reach features through '
          'app/providers.dart, which is a door features are already allowed '
          '(test/architecture/feature_isolation_test.dart).',
    );
  });

  test('the families it guards are the families pubspec.yaml declares', () {
    // A guard listing families the app does not use would pass forever while
    // the real ones drifted past it.
    const bundled = <String>['Noto Sans', 'Noto Sans JP', 'JetBrains Mono'];
    for (final family in bundled) {
      expect(
        fontFamilyLiterals,
        contains("'$family'"),
        reason:
            '$family is bundled and declared but not guarded, so a feature '
            'could name it directly and nothing would notice.',
      );
    }
  });

  test('the detector finds what it is looking for', () {
    // The negative control every architecture test in this directory carries:
    // a scan that silently matches nothing passes just as loudly as one that
    // works.
    expect(
      forbiddenTokensIn(
        "TextStyle(fontFamily: 'monospace')",
        fontFamilyLiterals,
      ),
      <String>["'monospace'"],
    );
    expect(
      forbiddenTokensIn(
        'TextStyle(fontFamily: monoFamily)',
        fontFamilyLiterals,
      ),
      isEmpty,
    );
  });
}
