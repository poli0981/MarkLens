/// The Inno Setup script, checked without an Inno Setup compiler.
///
/// `iscc` compiles it — on the runner, and on a dev box once Inno Setup is
/// installed — so why assert anything here? Because the two mistakes that
/// actually cost something are not compile errors: an installer that quietly
/// asks for administrator rights, and one that registers no file associations
/// at all. Both compile perfectly and both are only visible on a clean machine.
///
/// So this asserts the *decisions*, and runs on every PR and on both operating
/// systems, where `iscc` runs on neither.
///
/// The one syntactic thing it does check is the `{cm:...}` message constants,
/// and that is here because I made exactly that mistake while writing the
/// script: `{cm:FileAssociations}` used without a `[CustomMessages]` entry is a
/// compile error, and before Inno was installed locally it would have been a
/// compile error that only reproduced in CI.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _main = 'packaging/windows/marklens.iss';
const String _associations = 'packaging/windows/associations.iss';

/// The `AppId` generated once at M4. Recorded in `docs/11_PACKAGING_UPDATE.md`.
///
/// Pinned here because changing it is invisible and expensive: Windows keys an
/// installation on this GUID, so a new one turns an upgrade into a second copy
/// with its own uninstall entry, and the old one can no longer be removed by
/// the new installer.
const String _appId = 'D40DDB92-8D60-4FA4-8D52-4C526834C355';

/// Message constants Inno's own `Default.isl` defines.
///
/// Short on purpose: this is not a copy of Inno's message file, it is the list
/// of standard messages these two scripts use. Anything else has to be ours.
const List<String> _standardMessages = <String>[
  'AssocFileExtension',
  'AdditionalIcons',
  'CreateDesktopIcon',
  'LaunchProgram',
];

/// Reads a repo file.
///
/// Throws rather than calling `expect`, because these are read at the top of
/// `main()` to build the test list, and `expect` outside a test body is an
/// `OutsideTestException` that reports as "failed to load" rather than as the
/// missing file it is.
String _read(String relative) {
  final file = File(relative);
  if (!file.existsSync()) {
    throw StateError('$relative is missing.');
  }
  return file.readAsStringSync();
}

/// A `Directive=value` line from `[Setup]`.
String? _directive(String script, String name) => RegExp(
  '^$name=(.*)\$',
  multiLine: true,
).firstMatch(script)?.group(1)?.trim();

void main() {
  final main = _read(_main);
  final associations = _read(_associations);

  test('it installs per-user, without asking for administrator', () {
    // doc 11: "Per-user (PrivilegesRequired=lowest), install under
    // %LocalAppData%". Inno's default is to request elevation, so this is an
    // opt-out, and getting it wrong produces a UAC prompt rather than an error.
    expect(_directive(main, 'PrivilegesRequired'), 'lowest');
    expect(
      _directive(main, 'DefaultDirName'),
      startsWith('{localappdata}'),
      reason:
          'A per-user installer writing to {commonpf} would fail for exactly '
          'the users it is meant to serve.',
    );
  });

  test('it includes the association rules rather than restating them', () {
    // The associations are a policy file authored at M3 and wired at M4. An
    // installer that dropped the #include would compile, install, and register
    // nothing - the one failure a user reports as "it does not work".
    expect(main, contains('#include "associations.iss"'));
    expect(associations, contains(r'Software\Classes\MarkLens.Document'));
    expect(
      associations,
      isNot(contains('HKLM')),
      reason:
          'Every association key is HKCU; a per-user install cannot write '
          'HKLM without the elevation it deliberately does not request.',
    );
  });

  test('the version comes from the command line and cannot be forgotten', () {
    // pubspec.yaml is the single source of truth (doc 11) and build.ps1 reads
    // it. A version literal here would be a fourth copy with no guard - and
    // worse, a *stale* one is a working installer that lies about itself.
    expect(main, contains('#ifndef AppVersion'));
    expect(_directive(main, 'AppVersion'), '{#AppVersion}');
    expect(
      RegExp(r'^#define\s+AppVersion', multiLine: true).hasMatch(main),
      isFalse,
      reason: 'AppVersion must come from /DAppVersion=, not from a #define.',
    );
  });

  test('the AppId is the one recorded in doc 11', () {
    expect(
      _directive(main, 'AppId'),
      '{{$_appId}',
      reason:
          'Windows keys the installation on this GUID. A new one orphans every '
          'existing install: the upgrade becomes a second copy, and the old '
          'uninstall entry outlives it.',
    );
  });

  test('every message constant is standard or ours', () {
    // The compile error this file exists to catch. {cm:X} resolves against
    // Inno's message files plus [CustomMessages]; a name in neither fails the
    // build, and the build only runs in CI.
    final defined =
        RegExp(
            r'^english\.(\w+)=',
            multiLine: true,
          ).allMatches(main).map((m) => m.group(1)!).toSet()
          ..addAll(_standardMessages);

    final used = RegExp(r'\{cm:(\w+)')
        .allMatches('$main\n$associations')
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      used,
      isNotEmpty,
      reason: 'No {cm:...} found - has the syntax changed?',
    );
    expect(
      used.difference(defined),
      isEmpty,
      reason:
          'These message constants are used and neither standard nor defined '
          'in [CustomMessages]. iscc fails on them, and iscc only runs in CI.',
    );
  });

  test(
    '{cm:AssocFileExtension} has a [Languages] section to resolve against',
    () {
      // Without one, Inno loads no message file at all and every standard
      // constant above is undefined - including the two the association tasks
      // use, which live in the file that does not declare the section.
      expect(main, contains('[Languages]'));
      expect(main, contains('compiler:Default.isl'));
    },
  );

  test('it emits the filename doc 11 names in the artefact table', () {
    expect(
      _directive(main, 'OutputBaseFilename'),
      '{#AppName}-Setup-{#AppVersion}',
    );
    expect(
      _read('docs/11_PACKAGING_UPDATE.md'),
      contains('`MarkLens-Setup-x.y.z.exe`'),
      reason:
          'The release workflow, the README and SHA256SUMS all name these '
          'files; the installer has to produce the one the table promises.',
    );
  });

  test('it ships the whole bundle, not just the exe', () {
    // A Flutter Windows build is an exe plus data\ - flutter_assets, app.so and
    // icudtl.dat. Installing only the exe produces a program that starts and
    // immediately dies, which is a worse failure than one that does not start.
    expect(main, contains(r'Source: "{#BuildDir}\*"'));
    expect(main, contains('recursesubdirs'));
    expect(
      main,
      contains(
        r'#define BuildDir       "..\..\build\windows\x64\runner\Release"',
      ),
      reason: 'The source directory has to be where flutter build writes.',
    );
  });

  test('uninstall keeps the config directory unless asked', () {
    // The only deletion in MarkLens. Rule 1 covers the user's documents, not
    // the app's own two files, so this is permitted - but it is opt-in, and a
    // checkbox that defaulted to checked would lose somebody's tabs on a
    // reinstall.
    expect(main, contains('RemoveDataCheckBox.Checked := False'));
    expect(main, contains('usPostUninstall'));
    expect(
      main,
      contains(r"ExpandConstant('{userappdata}\poli0981\MarkLens\marklens')"),
      reason:
          'The config path is built from CompanyName and ProductName by '
          'path_provider_windows (doc 05). If those move, this moves.',
    );
  });
}
