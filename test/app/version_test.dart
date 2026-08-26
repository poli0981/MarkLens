/// The version MarkLens prints has to be the version it is.
///
/// `--version` runs before the Flutter binding exists, so it cannot ask
/// `package_info_plus`; the constant is hand-kept instead, and this is what
/// keeps "hand-kept" from meaning "wrong". The doc 15 release checklist bumps
/// `pubspec.yaml`, and this test is what notices when only one of them moved.
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
}
