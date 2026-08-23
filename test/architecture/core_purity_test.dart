import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// CLAUDE.md rule 3: `lib/core/` is pure Dart. No `package:flutter`, no
/// Flutter plugin, no reaching up into `app/` or `features/`.
///
/// This is an **allowlist**: an import that is not named below fails, so a
/// newly added package has to be argued for rather than silently inherited
/// (`docs/02_ARCHITECTURE.md`).
const Set<String> allowedPurePackages = <String>{
  'markdown', // parser/AST — the pipeline's whole job
  'watcher', // file/folder watching
  'args', // CLI argument parsing
  'riverpod', // pure-Dart half of Riverpod; flutter_riverpod is NOT allowed
  'meta', // annotations only
  'path', // path manipulation
  'collection', // small pure-Dart utilities
};

void main() {
  group('core purity', () {
    final sources = dartSourcesUnder('lib/core');

    test('there is core source to check', () {
      expect(
        sources,
        isNotEmpty,
        reason: 'lib/core/ is empty — this test would pass vacuously.',
      );
    });

    test('no file under lib/core imports Flutter', () {
      for (final file in sources) {
        for (final uri in file.imports) {
          expect(
            uri.startsWith('package:flutter'),
            isFalse,
            reason:
                '${file.path} imports $uri.\n'
                'core/ is pure Dart (CLAUDE.md rule 3). If this is rendering '
                'code it belongs in features/reader/rendering/; if it needs a '
                'Flutter plugin, resolve it in app/providers.dart and inject '
                'the result.',
          );
        }
      }
    });

    test('lib/core imports only allowlisted packages', () {
      for (final file in sources) {
        for (final uri in file.imports) {
          if (uri.startsWith('dart:')) continue;
          if (uri.startsWith('package:marklens/core/')) continue;

          final package = packageNameOf(uri);
          expect(
            package,
            isNotNull,
            reason:
                '${file.path}: relative import "$uri". '
                'Use package: imports throughout lib/.',
          );
          expect(
            allowedPurePackages,
            contains(package),
            reason:
                '${file.path} imports $uri, which is not on the core '
                'allowlist in this test. Either it is a Flutter package (move '
                'the code out of core/), or it is a new pure-Dart dependency — '
                'in which case add it here, to docs/01_TECH_STACK.md and to '
                'legal/THIRD_PARTY_NOTICES.md in the same PR (rule 10).',
          );
        }
      }
    });
  });

  // The detector itself is tested, so this file cannot quietly stop working.
  group('core purity detector', () {
    test('flags a Flutter import', () {
      const violating = "import 'package:flutter/material.dart';";
      expect(importsOf(violating), contains('package:flutter/material.dart'));
    });

    test('ignores an import that only appears in a comment', () {
      const commented = "/// import 'package:flutter/material.dart';";
      expect(importsOf(stripComments(commented)), isEmpty);
    });

    test('reads the package name out of a package URI', () {
      expect(packageNameOf('package:markdown/markdown.dart'), 'markdown');
      expect(packageNameOf('dart:io'), isNull);
    });
  });
}
