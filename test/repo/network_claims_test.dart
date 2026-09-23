/// Every place that tells a reader what MarkLens sends over the network, held
/// to what the code does.
///
/// From M4 to v1.0.1 five copies called the update check "opt-in" - the
/// AppStream description, the Debian control file, the README, SECURITY.md and
/// doc 10 - while `NetworkSettings` has defaulted it to on since it was
/// written. The package descriptions are what a software centre shows before
/// anyone reads a line of the docs, so a wrong one is a false statement about
/// privacy in the one place a person decides whether to install.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _settings = 'lib/core/models/app_settings.dart';
const String _metainfo = 'packaging/linux/dev.poli0981.marklens.metainfo.xml';
const String _control = 'packaging/linux/deb/DEBIAN/control.in';

/// The copies a reader sees. Each describes the network features in its own
/// words; none may call them opt-in.
const List<String> _copies = <String>[
  'README.md',
  'SECURITY.md',
  'docs/10_SECURITY_PRIVACY.md',
  _metainfo,
  _control,
];

/// Reads a repo file, throwing rather than calling `expect`: these are read at
/// the top of `main()`, where `expect` reports "failed to load" instead of the
/// missing file.
String _read(String relative) {
  final file = File(relative);
  if (!file.existsSync()) {
    throw StateError('$relative is missing.');
  }
  return file.readAsStringSync();
}

/// Text with every run of whitespace collapsed to one space, so a sentence
/// wrapped across XML indentation or Debian continuation lines reads as one.
String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final settings = _read(_settings);

  test('the code defaults are the ones the copies describe', () {
    // If either default ever changes, every sentence below is wrong at once;
    // this is the test that says so.
    expect(settings, contains('this.updateCheck = true'));
    expect(settings, contains('this.allowRemoteImages = false'));
  });

  test('no copy calls either network feature opt-in', () {
    for (final path in _copies) {
      expect(
        _read(path).toLowerCase(),
        isNot(contains('opt-in')),
        reason:
            '$path: the update check is on by default. Say "on by default" '
            'and "off by default"; "opt-in" was wrong here once.',
      );
    }
  });

  test('the package descriptions say what is on and what is off', () {
    for (final path in <String>[_metainfo, _control]) {
      final text = _flat(_read(path));
      expect(
        text,
        contains('an update check against GitHub Releases, at most once a day'),
        reason: path,
      );
      expect(text, contains('on by default'), reason: path);
      expect(
        text,
        contains('remote images, which are off by default'),
        reason: path,
      );
      expect(text, contains('no telemetry'), reason: path);
    }
  });
}
