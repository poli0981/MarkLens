import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// `docs/02_ARCHITECTURE.md`: `features/X` never imports `features/Y`.
/// Cross-feature communication goes through `app/providers.dart` only, which
/// is what keeps sidebar, tabs and reader independently testable.
void main() {
  group('feature isolation', () {
    final sources = dartSourcesUnder('lib/features');

    test('no feature imports another feature directly', () {
      for (final file in sources) {
        final owner = _featureOf(file.path);
        expect(
          owner,
          isNotNull,
          reason: '${file.path} is not inside a feature directory.',
        );

        for (final uri in file.imports) {
          const prefix = 'package:marklens/features/';
          if (!uri.startsWith(prefix)) continue;

          final target = uri.substring(prefix.length).split('/').first;
          expect(
            target,
            owner,
            reason:
                '${file.path} imports $uri.\n'
                'Feature "$owner" may not reach into feature "$target". '
                'Route it through a provider in app/providers.dart.',
          );
        }
      }
    });

    test('no feature imports app/ except the composition root and the '
        'theme', () {
      // Two entries, and the difference between them matters. providers.dart
      // is the composition root: app-level *wiring*. app/theme/ is app-level
      // *data* — the eight doc 06 tokens, which every feature draws from and
      // reads through Theme.of(context). Doc 02's own target tree puts the
      // theme under app/, so a rule that allowed only providers.dart would
      // make its own layout unbuildable.
      //
      // What the rule is actually for is untouched: a feature still cannot
      // reach into another feature, and still cannot reach into app
      // behaviour.
      const allowed = <String>{
        'package:marklens/app/providers.dart',
        'package:marklens/app/theme/reader_tokens.dart',
      };
      for (final file in sources) {
        for (final uri in file.imports) {
          const prefix = 'package:marklens/app/';
          if (!uri.startsWith(prefix)) continue;
          expect(
            allowed,
            contains(uri),
            reason:
                '${file.path} imports $uri. Features see app/ only through '
                'its composition root and its theme tokens.',
          );
        }
      }
    });
  });

  group('feature isolation detector', () {
    test('identifies the owning feature of a path', () {
      expect(_featureOf('lib/features/sidebar/sidebar_tree.dart'), 'sidebar');
      expect(
        _featureOf('lib/features/reader/rendering/code_highlighter.dart'),
        'reader',
      );
      expect(_featureOf('lib/core/models/doc_model.dart'), isNull);
    });
  });
}

/// Returns the feature directory owning [path], or `null` if it is not under
/// `lib/features/`.
String? _featureOf(String path) {
  const prefix = 'lib/features/';
  if (!path.startsWith(prefix)) return null;
  final rest = path.substring(prefix.length).split('/');
  return rest.length < 2 ? null : rest.first;
}
