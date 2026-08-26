/// `docs/07_FILES_AND_WATCH.md`: "Natural sort within each directory
/// (`2.md` < `10.md`)".
///
/// The ordering also has to be *total*, or a sort of the sidebar is unstable
/// and entries swap places between two scans of an unchanged folder.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/files/natural_sort.dart';

List<String> _sorted(List<String> names) =>
    List<String>.of(names)..sort(compareNatural);

void main() {
  group('numbers compare as numbers', () {
    test('the case docs/07 names', () {
      expect(_sorted(<String>['10.md', '2.md']), <String>['2.md', '10.md']);
    });

    test('a longer run of chapters', () {
      expect(
        _sorted(<String>[
          'ch10.md',
          'ch2.md',
          'ch1.md',
          'ch20.md',
          'ch3.md',
          'ch100.md',
        ]),
        <String>[
          'ch1.md',
          'ch2.md',
          'ch3.md',
          'ch10.md',
          'ch20.md',
          'ch100.md',
        ],
      );
    });

    test('leading zeros do not change the value', () {
      expect(_sorted(<String>['0010.md', '2.md']), <String>['2.md', '0010.md']);
      // `07` and `7` are the same number, so they land next to each other and
      // both before `8` — but they are still different names, and the ordering
      // has to stay total, so they are not reported as equal.
      expect(
        _sorted(<String>['8.md', '07.md', '7.md']),
        <String>['07.md', '7.md', '8.md'],
      );
      expect(compareNatural('07.md', '7.md'), isNot(0));
    });

    test('a number too large for an int still orders', () {
      // Parsing would throw here; the comparison works on the digits.
      expect(
        compareNatural(
          'id-99999999999999999999999.md',
          'id-99999999999999999999998.md',
        ),
        greaterThan(0),
      );
    });

    test('several number runs in one name', () {
      expect(
        _sorted(<String>['v1.10.md', 'v1.2.md', 'v1.9.md']),
        <String>['v1.2.md', 'v1.9.md', 'v1.10.md'],
      );
    });
  });

  group('text compares case-insensitively', () {
    test('uppercase does not sort before everything', () {
      expect(
        _sorted(<String>['banana.md', 'Apple.md', 'cherry.md']),
        <String>['Apple.md', 'banana.md', 'cherry.md'],
        reason:
            'a plain string sort puts every capitalised name first, which is '
            'not how a file list should read',
      );
    });

    test('a prefix comes before the longer name', () {
      expect(_sorted(<String>['readme.md', 'read.md']), <String>[
        'read.md',
        'readme.md',
      ]);
    });
  });

  group('the ordering is total', () {
    test('names differing only in case are not equal', () {
      expect(
        compareNatural('README.md', 'readme.md'),
        isNot(0),
        reason:
            'reporting them equal makes a sort unstable, and the sidebar '
            'reshuffles between scans of an unchanged folder',
      );
    });

    test('identical names are equal', () {
      expect(compareNatural('a.md', 'a.md'), 0);
    });

    test('sorting is antisymmetric across a mixed set', () {
      const names = <String>[
        '2.md',
        '10.md',
        'Apple.md',
        'apple.md',
        'Cài đặt.md',
        '設定.md',
        '',
        'a',
      ];
      for (final a in names) {
        for (final b in names) {
          expect(
            compareNatural(a, b).sign,
            -compareNatural(b, a).sign,
            reason: 'compare($a, $b) and compare($b, $a) disagree',
          );
        }
      }
    });

    test('non-ASCII names order deterministically', () {
      final once = _sorted(<String>['設定.md', 'Cài đặt.md', 'zebra.md']);
      final twice = _sorted(<String>['Cài đặt.md', 'zebra.md', '設定.md']);
      expect(once, twice);
    });
  });

  group('degenerate input', () {
    test('empty strings', () {
      expect(compareNatural('', ''), 0);
      expect(compareNatural('', 'a'), lessThan(0));
      expect(compareNatural('a', ''), greaterThan(0));
    });

    test('digits only', () {
      expect(_sorted(<String>['10', '9', '100']), <String>['9', '10', '100']);
    });
  });
}
