/// Help → Third-party Licenses has to list the fonts we ship.
///
/// It lists every *package* without being asked, because Flutter seeds
/// [LicenseRegistry] from the dependency graph. Assets get nothing, so before
/// M4 the licence page would have shown 1.4 MB of package notices and no
/// mention of the three OFL fonts in the binary beside them. That is an
/// obligation of the licence, not a courtesy.
///
/// The registration lives in a named function precisely so this test can drive
/// the same code `main()` drives; asserting against a private copy would prove
/// nothing about the app.
///
/// Note what this deliberately does *not* do: drain
/// `LicenseRegistry.licenses`. That also runs Flutter's own collector, which
/// loads the `NOTICES` asset through a worker and never completes under a
/// widget-test binding — measured, not guessed: `flutter_tester` sat at 0% CPU
/// until it was killed. So the stream this file contributes is read directly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/license_registry.dart';

/// Serves the licence texts from disk, which is what the real asset bundle
/// does once `pubspec.yaml`'s `assets:` entry puts them there.
class _FakeBundle extends CachingAssetBundle {
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final bytes = utf8.encode(
      'Copyright placeholder\n\nThis Font Software is licensed under the SIL '
      'Open Font License, Version 1.1.\n',
    );
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  setUp(debugResetBundledFontLicenses);
  tearDown(debugResetBundledFontLicenses);

  test('the three bundled families each get an OFL entry', () async {
    final bundle = _FakeBundle();
    final entries = await bundledFontLicenses(bundle).toList();

    expect(
      entries.expand((e) => e.packages).toList(),
      <String>['Noto Sans', 'Noto Sans JP', 'JetBrains Mono'],
      reason:
          'Each family ships in the binary, so each has to appear under Help → '
          'Third-party Licenses.',
    );

    for (final entry in entries) {
      expect(
        entry.paragraphs.map((p) => p.text).join(' '),
        contains('SIL Open Font License'),
        reason:
            'The entry for ${entry.packages.join(", ")} is not an OFL text — a '
            'wrong asset path would otherwise ship a blank licence page.',
      );
    }
  });

  test('every licence asset it asks for is one pubspec.yaml ships', () async {
    // The asset paths are string literals, so a typo is invisible until a user
    // opens the licence page and the load throws.
    final bundle = _FakeBundle();
    await bundledFontLicenses(bundle).toList();

    expect(bundle.requested, isNotEmpty);
    for (final key in bundle.requested) {
      expect(
        key,
        startsWith('legal/licenses/'),
        reason: 'pubspec.yaml only ships legal/licenses/ as an asset.',
      );
      expect(
        File(key).existsSync(),
        isTrue,
        reason: '$key does not exist, so the real bundle cannot serve it.',
      );
    }
  });

  test('registering twice registers once', () {
    // LicenseRegistry.addLicense appends, and there is no way to remove an
    // entry. A second call would list all three fonts twice.
    registerBundledFontLicenses();
    registerBundledFontLicenses();
    expect(debugRegistrationCount, 1);
  });
}
