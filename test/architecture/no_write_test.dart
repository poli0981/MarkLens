import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// CLAUDE.md rule 1 / `docs/10_SECURITY_PRIVACY.md` invariant 5: MarkLens
/// never writes, renames or deletes a user document. The only writes in the
/// codebase are the two config-directory stores and the user-pointed
/// diagnostic log export.
///
/// This test is the automated half; the manual Process Monitor / `strace` pass
/// on the release checklist is the other half.
const List<String> writeApis = <String>[
  'writeAsString',
  'writeAsBytes',
  'openWrite',
  'FileMode.write',
  'FileMode.writeOnly',
  'FileMode.append',
  '.createSync(',
  '.deleteSync(',
  '.renameSync(',
  '.copySync(',
  '.delete(',
  '.rename(',
  '.copy(',
];

/// Directories permitted to write. Everything else in `lib/` may not.
const List<String> writeAllowedPrefixes = <String>[
  // session.json / settings.json, atomic writes (docs/05).
  'lib/core/session/',
  'lib/core/settings/',
  // Help → Export diagnostic log: the one user-pointed write outside the
  // config dir (docs/02_ARCHITECTURE.md, "Logging").
  'lib/features/about/',
];

void main() {
  group('read-only enforcement', () {
    final sources = dartSourcesUnder('lib');

    test('there is source to check', () {
      expect(sources, isNotEmpty, reason: 'lib/ is empty.');
    });

    test('no write-mode file API outside the allowed directories', () {
      for (final file in sources) {
        if (hasPrefix(file.path, writeAllowedPrefixes)) continue;

        final found = forbiddenTokensIn(file.code, writeApis);
        expect(
          found,
          isEmpty,
          reason:
              '${file.path} uses $found.\n'
              'MarkLens never writes user files (CLAUDE.md rule 1). If this is '
              'a legitimate config-directory write, it belongs in '
              'core/session/ or core/settings/; if it is the log export, it '
              'belongs in features/about/. Widening this allowlist needs a '
              'reason in the PR description.',
        );
      }
    });
  });

  group('read-only detector', () {
    test('flags a write call', () {
      const violating = 'await File(path).writeAsString(text);';
      expect(
        forbiddenTokensIn(violating, writeApis),
        contains('writeAsString'),
      );
    });

    test('does not flag copyWith', () {
      const benign = 'final next = settings.copyWith(fontScale: 1.2);';
      expect(forbiddenTokensIn(benign, writeApis), isEmpty);
    });

    test('does not flag a write mentioned only in a doc comment', () {
      const commented = '/// Never call writeAsString here.';
      expect(forbiddenTokensIn(stripComments(commented), writeApis), isEmpty);
    });
  });
}
