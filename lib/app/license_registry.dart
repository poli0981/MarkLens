/// The bundled fonts' licences, which nothing else would show.
///
/// `showLicensePage` reads [LicenseRegistry], and Flutter seeds that with the
/// `LICENSE` file of every *package* in the dependency graph — which is why
/// `NOTICES.Z` in a release bundle is 1.4 MB. It knows nothing about assets, so
/// three OFL-1.1 fonts shipped in `fonts/` would appear nowhere in the app at
/// all. That is an attribution obligation of the licence rather than a nicety:
/// the OFL requires its text to travel with the font.
///
/// Registered from a named function rather than inline in `main()` so a widget
/// test can call the same code the app calls. Registering only in `main()`
/// would leave the one thing worth testing untested.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence files, and which families each covers.
///
/// Keyed by asset path so the entry and the file cannot drift silently: a typo
/// here throws when the licence page is opened, and
/// `test/app/license_registry_test.dart` opens it.
const Map<String, List<String>> _fontLicences = <String, List<String>>{
  'legal/licenses/OFL-1.1-NotoSans.txt': <String>['Noto Sans'],
  'legal/licenses/OFL-1.1-NotoSansJP.txt': <String>['Noto Sans JP'],
  'legal/licenses/OFL-1.1-JetBrainsMono.txt': <String>['JetBrains Mono'],
};

/// Whether [registerBundledFontLicenses] has already run.
///
/// `LicenseRegistry.addLicense` appends, so calling it twice lists every font
/// twice. `main()` runs once, but a widget test suite pumps many apps.
bool _registered = false;

/// How many times [registerBundledFontLicenses] has actually registered.
int _registrations = 0;

/// Adds the bundled fonts' OFL texts to [LicenseRegistry].
///
/// Idempotent. Call once during bootstrap, before any licence page can open.
void registerBundledFontLicenses({AssetBundle? bundle}) {
  if (_registered) {
    return;
  }
  _registered = true;
  _registrations++;
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() => bundledFontLicenses(assets));
}

/// The entries [registerBundledFontLicenses] contributes.
///
/// Public so a test can read them without draining [LicenseRegistry.licenses],
/// which also runs Flutter's own collector — that one loads the `NOTICES` asset
/// through a worker, and in a widget-test binding it simply never completes.
/// Found by hanging: `flutter_tester` sat at 0% CPU for seven minutes.
Stream<LicenseEntry> bundledFontLicenses(AssetBundle bundle) async* {
  for (final licence in _fontLicences.entries) {
    yield LicenseEntryWithLineBreaks(
      licence.value,
      await bundle.loadString(licence.key),
    );
  }
}

/// How many registrations have happened. See [debugResetBundledFontLicenses].
@visibleForTesting
int get debugRegistrationCount => _registrations;

/// Resets the guard and the counter so a test can start from a known state.
@visibleForTesting
void debugResetBundledFontLicenses() {
  _registered = false;
  _registrations = 0;
}
