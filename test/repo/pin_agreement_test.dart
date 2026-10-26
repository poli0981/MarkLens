/// The Flutter pin and the golden image live in more than one file each, and
/// doc 01 says they "must never disagree". That was a rule nobody could enforce
/// by reading: the version appears in `ci.yml`, in `watch-observation.yml`, in
/// the goldens Dockerfile and in doc 01 itself, and three of those four are
/// files a person opens once a year.
///
/// This is the enforcement. It is deliberately text-scanning rather than YAML
/// parsing — `package:yaml` is only in the tree transitively, so importing it
/// would trip `depend_on_referenced_packages` and fail `flutter analyze`, which
/// gates every PR (doc 13 prefers our own fifty lines anyway).
///
/// It lives in `test/repo/` rather than `test/architecture/`: those tests are
/// about the app's internal boundaries, these are about the repo's agreements
/// with itself, and nothing under `.github/`, `tool/` or `packaging/` is
/// covered by any other test in this suite.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that name the Flutter version, and how to find it in each.
///
/// Seven: the five that build something, plus the two a reader trusts — the
/// README's stack line and the notices table, which both still said 3.47.1 on
/// the day the first upgrade landed, because nothing here read them. That is
/// the point: doc 01 says they "must never disagree", and files kept in step
/// by memory is a rule that is already broken somewhere nobody has looked.
const Map<String, String> _flutterPinSources = <String, String>{
  '.github/workflows/ci.yml': r'FLUTTER_VERSION:\s*"([\d.]+)"',
  '.github/workflows/release.yml': r'FLUTTER_VERSION:\s*"([\d.]+)"',
  '.github/workflows/watch-observation.yml': r'flutter-version:\s*"([\d.]+)"',
  'tool/goldens/Dockerfile': r'ARG\s+FLUTTER_VERSION=([\d.]+)',
  'tool/linux/Dockerfile': r'ARG\s+FLUTTER_VERSION=([\d.]+)',
  'docs/01_TECH_STACK.md': r'\*\*Flutter\s+([\d.]+)\s+stable\*\*',
  'README.md': r'\*\*Stack:\*\*\s+Flutter\s+([\d.]+)\s+stable',
  'legal/THIRD_PARTY_NOTICES.md':
      r'\|\s*Flutter SDK\s*\|[^|\n]*\|[^|\n]*\|\s*([\d.]+)\s*\|',
};

/// Every exact pin under `dependencies:` — what ships — as name → version.
///
/// SDK packages (`flutter`, `flutter_localizations`) carry no version line and
/// fall out of the pattern by themselves.
Map<String, String> _shippedPins() {
  final pubspec = _read('pubspec.yaml');
  final start = pubspec.indexOf(RegExp(r'^dependencies:$', multiLine: true));
  final end = pubspec.indexOf(RegExp(r'^dev_dependencies:$', multiLine: true));
  expect(
    start != -1 && end > start,
    isTrue,
    reason: 'pubspec.yaml no longer has dependencies: before dev_dependencies:',
  );
  return <String, String>{
    for (final RegExpMatch m in RegExp(
      r'^  ([a-z0-9_]+):\s+(\d+\.\d+\.\d+)\s*$',
      multiLine: true,
    ).allMatches(pubspec.substring(start, end)))
      m.group(1)!: m.group(2)!,
  };
}

/// The markdown table rows of [text] whose first cell names [package].
///
/// "Names" means as a whole entry: `riverpod / flutter_riverpod` names both,
/// `markdown (Dart team)` names `markdown`, but `highlight.js` does not name
/// `highlight` and `path_provider` does not name `path`.
List<List<String>> _rowsNaming(String text, String package) {
  final name = RegExp('(^|[\\s/+])${RegExp.escape(package)}(\$|[\\s/+(])');
  return <List<String>>[
    for (final String line in text.split('\n'))
      if (line.trimLeft().startsWith('|'))
        line.split('|').map((cell) => cell.trim()).toList()
          ..removeAt(0)
          ..removeLast(),
  ].where((cells) => cells.isNotEmpty && name.hasMatch(cells.first)).toList();
}

/// Doc 01's "Dependency table" section alone. The renderer and highlighter
/// tables above it name packages too — with the versions that were evaluated,
/// which is history rather than a pin.
String _doc01DependencyTable() {
  final doc = _read('docs/01_TECH_STACK.md');
  final start = doc.indexOf('## Dependency table');
  expect(start, isNot(-1), reason: 'doc 01 lost its "Dependency table".');
  final end = doc.indexOf('\n## ', start + 1);
  return doc.substring(start, end == -1 ? doc.length : end);
}

String _read(String relative) {
  final file = File(relative);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        '$relative is missing. If it moved, this test moved with it — the pin '
        'it carries still has to agree with the others.',
  );
  return file.readAsStringSync();
}

String _single(String relative, String pattern) {
  final matches = RegExp(pattern).allMatches(_read(relative)).toList();
  expect(
    matches,
    hasLength(1),
    reason:
        '$relative should state its version exactly once, matching /$pattern/. '
        'Found ${matches.length}. Two of them is how they start to disagree.',
  );
  return matches.single.group(1)!;
}

void main() {
  test('every file that names the Flutter version names the same one', () {
    final found = <String, String>{
      for (final MapEntry<String, String> source in _flutterPinSources.entries)
        source.key: _single(source.key, source.value),
    };

    final distinct = found.values.toSet();
    expect(
      distinct,
      hasLength(1),
      reason:
          'The Flutter pin disagrees across files: $found. doc 01 is the '
          'source of truth; bump every one of these together, never just the '
          'runner.',
    );
  });

  test('the golden job runs on the image its own container is built from', () {
    // A golden is a byte comparison, so the image that checks one has to be the
    // image that made it. Generating the first goldens on Windows against an
    // Ubuntu reference already cost four of five images once (doc 12), and
    // `ubuntu-latest` moving from 24.04 to 26.04 would do the same thing to all
    // of them at once — while looking like a flake rather than a version bump.
    final dockerfile = _read('tool/goldens/Dockerfile');
    final from = RegExp(
      r'^FROM\s+ubuntu:([\d.]+)',
      multiLine: true,
    ).firstMatch(dockerfile);
    expect(
      from,
      isNotNull,
      reason: 'tool/goldens/Dockerfile no longer starts FROM an ubuntu tag.',
    );

    final ci = _read('.github/workflows/ci.yml');
    final goldenJob = RegExp(
      r'^  golden:\n(?<body>(?:.*\n)*?)^  \w',
      multiLine: true,
    ).firstMatch(ci);
    expect(
      goldenJob,
      isNotNull,
      reason: 'ci.yml no longer has a top-level `golden:` job.',
    );

    final runsOn = RegExp(r'runs-on:\s*ubuntu-([\d.]+)')
        .firstMatch(goldenJob!.namedGroup('body')!);
    expect(
      runsOn,
      isNotNull,
      reason:
          'The golden job must pin an explicit ubuntu image. `ubuntu-latest` '
          'is a moving target and goldens are the thing that notices it '
          'moving.',
    );

    expect(
      runsOn!.group(1),
      from!.group(1),
      reason:
          'The golden job runs on ubuntu-${runsOn.group(1)} while '
          'tool/goldens/Dockerfile builds on ubuntu:${from.group(1)}. The '
          'references were generated by the second and are compared by the '
          'first; they have to be the same image.',
    );
  });

  // Rule 10 says a moved pin re-checks its licence and updates doc 01 and the
  // notices in the same PR. Since Dependabot opens the monthly batch
  // (.github/dependabot.yml), that PR is written by something that cannot do
  // either — so these two are what keep it red until a person has.
  group('every shipped pin agrees with', () {
    test('pubspec.yaml has pins to check', () {
      expect(_shippedPins(), contains('markdown'));
    });

    test("doc 01's dependency table", () {
      final table = _doc01DependencyTable();
      _shippedPins().forEach((package, version) {
        final rows = _rowsNaming(table, package);
        expect(
          rows,
          hasLength(1),
          reason:
              "$package should have exactly one row in doc 01's dependency "
              'table; found ${rows.length}. A new dependency needs one, with '
              'its licence (CLAUDE.md rule 10).',
        );
        expect(
          rows.single.last,
          contains('`$version`'),
          reason:
              'doc 01 pins $package at "${rows.single.last}"; pubspec.yaml '
              'says $version. Re-check the licence, then update the row.',
        );
      });
    });

    test('legal/THIRD_PARTY_NOTICES.md', () {
      final notices = _read('legal/THIRD_PARTY_NOTICES.md');
      _shippedPins().forEach((package, version) {
        final rows = _rowsNaming(notices, package);
        expect(
          rows,
          hasLength(1),
          reason:
              '$package ships in the binary, so it needs exactly one row in '
              'the notices; found ${rows.length}.',
        );
        expect(
          rows.single.last,
          version,
          reason:
              'The notices list $package at "${rows.single.last}"; the binary '
              'ships $version.',
        );
      });
    });
  });

  test('doc 01 names the lint ruleset version that is pinned', () {
    // A dev dependency ships in nothing, so it has no notices row; doc 01
    // still states its version, and a batch bump would leave that stale.
    final pubspec = _read('pubspec.yaml');
    final pinned = RegExp(
      r'^  very_good_analysis:\s+(\d+\.\d+\.\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    expect(pinned, isNotNull, reason: 'very_good_analysis is not pinned.');
    expect(
      _read('docs/01_TECH_STACK.md'),
      contains('`very_good_analysis` **$pinned**'),
      reason: 'doc 01 does not name very_good_analysis $pinned.',
    );
  });
}
