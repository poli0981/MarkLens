import 'dart:io';

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
  // The atomic write itself: temp file, flush, rename. Both config files go
  // through it, so the discipline in docs/05 is implemented once rather than
  // copied twice. It is the implementation of the config-directory write, not
  // an exception to it — and it writes only inside the Directory it is handed,
  // which test/core/json_store_test.dart asserts rather than assumes.
  'lib/core/storage/',
  // session.json / settings.json, atomic writes (docs/05).
  'lib/core/session/',
  'lib/core/settings/',
  // instance.lock: which port the running window listens on, so a second
  // launch can hand its arguments over (docs/02, docs/03). Same config
  // directory, injected the same way, and asserted by
  // test/core/single_instance_test.dart to write nothing outside it.
  'lib/core/single_instance.dart',
];

void main() {
  group('read-only enforcement', () {
    final sources = dartSourcesUnder('lib');

    test('there is source to check', () {
      expect(sources, isNotEmpty, reason: 'lib/ is empty.');
    });

    test('the log export is not an exception, because it is not a write', () {
      // `lib/features/about/` was allowlisted here from M0 for Help → Export
      // Diagnostic Log, and at M3 the entry was **removed** rather than used.
      // `file_picker` 12's `saveFile` takes the bytes and writes them where
      // the reader pointed, so MarkLens's own code performs no file write
      // outside its config directory at all — which is a stronger statement of
      // rule 1 than the allowlist was (`docs/10_SECURITY_PRIVACY.md`).
      expect(
        writeAllowedPrefixes,
        isNot(contains('lib/features/about/')),
        reason:
            'if this is being added back, the export started writing again — '
            'and that needs a reason in the PR description',
      );
      expect(
        File('lib/features/about/log_export.dart').existsSync(),
        isTrue,
        reason: 'the export still exists; it just does not write',
      );
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
              'core/storage/, core/session/ or core/settings/. The '
              'diagnostic-log export is not a counter-example: it hands bytes '
              'to the platform save dialog and writes nothing itself. '
              'Widening this allowlist needs a reason in the PR description.',
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
