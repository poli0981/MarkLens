/// The version MarkLens prints has to be the version it is.
///
/// `--version` runs before the Flutter binding exists, so it cannot ask
/// `package_info_plus`; the constant is hand-kept instead, and this is what
/// keeps "hand-kept" from meaning "wrong". The doc 15 release checklist bumps
/// `pubspec.yaml`, and this test is what notices when only one of them moved.
///
/// It also checks the CHANGELOG, which was the third item on that checklist and
/// the only one nothing verified. A release whose notes are still headed
/// `[Unreleased]` is not a formatting slip: `gh release --generate-notes` fills
/// the GitHub page from commits, so the file people read in the repo is the one
/// that would silently stay wrong.
///
/// The git tag is the fourth place, and this test cannot see it. The release
/// workflow's `verify-version` job checks that one, because it is the copy
/// `UpdateService` actually parses (doc 11).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/version.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(declared, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(
      appVersion,
      declared,
      reason:
          'lib/app/version.dart says $appVersion and pubspec.yaml says '
          '$declared. Bump both, or --version lies about which build this is.',
    );
  });

  test('the CHANGELOG has a section for this version', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final headings = RegExp(
      r'^## \[([^\]]+)\]',
      multiLine: true,
    ).allMatches(changelog).map((m) => m.group(1)!).toList();

    expect(
      headings,
      contains(appVersion),
      reason:
          'CHANGELOG.md has no `## [$appVersion]` heading. Its headings are '
          '$headings. Keep a Changelog puts released versions in brackets; a '
          'release that ships with its notes still under [Unreleased] has '
          'notes nobody wrote.',
    );
    expect(
      headings.first,
      appVersion,
      reason:
          'The newest heading in CHANGELOG.md is ${headings.first}, not '
          '$appVersion. Keep a Changelog is newest-first.',
    );
  });
}
