/// The version MarkLens reports.
///
/// Hand-kept in step with `pubspec.yaml`, because `package_info_plus` needs a
/// Flutter binding and `--version` runs before there is one — starting the
/// engine to print a string would make the fastest path the slowest. That
/// package was pinned from M0 to M4 and imported by nothing on the strength of
/// a plan this constant had already replaced; it is no longer a dependency.
///
/// `test/app/version_test.dart` reads `pubspec.yaml` and fails if the two
/// drift, so "kept in step" is checked rather than remembered. The release
/// checklist in doc 15 bumps both together.
const String appVersion = '0.1.0';
