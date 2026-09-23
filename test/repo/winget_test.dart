/// The WinGet submission script, held to the files it copies from.
///
/// `tool/winget/submit.ps1` runs on the maintainer's machine after a release
/// is published (doc 11, "WinGet"), so nothing in CI ever executes it — and a
/// script that only runs on release day is where a stale constant waits. Every
/// value it checks a manifest against is a copy of something in this
/// repository: the product code is the installer's `AppId`, the publisher and
/// name are what the installed-apps list shows, the installer's name is the one
/// doc 11's table promises. This holds each copy to its source, and holds the
/// refusals that keep a wrong manifest from being submitted.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _script = 'tool/winget/submit.ps1';
const String _iss = 'packaging/windows/marklens.iss';
const String _doc = 'docs/11_PACKAGING_UPDATE.md';
const String _metainfo = 'packaging/linux/dev.poli0981.marklens.metainfo.xml';

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

/// The script's code. Carriage returns go, because `.gitattributes` checks
/// every `*.ps1` out as CRLF and a multi-line `$` does not match before `\r`;
/// comment-based help and whole-line comments go, so a sentence explaining a
/// check cannot stand in for the check.
String _powershellCode(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'<#[\s\S]*?#>'), '')
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

/// `$Name = 'value'` at the start of a line.
String? _constant(String code, String name) => RegExp(
  "^\\\$$name\\s*=\\s*'([^']*)'",
  multiLine: true,
).firstMatch(code)?.group(1);

/// A single-value row of doc 11's WinGet table: | `Field` | `value` | ...
String? _row(String doc, String field) => RegExp(
  '^\\| `$field` \\| `([^`]+)` \\|',
  multiLine: true,
).firstMatch(doc)?.group(1);

/// A `#define Name "value"` from the installer script.
String? _define(String iss, String name) => RegExp(
  '^#define\\s+$name\\s+"([^"]*)"',
  multiLine: true,
).firstMatch(iss)?.group(1);

/// A `Directive=value` line from `[Setup]`.
String? _directive(String iss, String name) => RegExp(
  '^$name=(.*)\$',
  multiLine: true,
).firstMatch(iss)?.group(1)?.trim();

void main() {
  final code = _powershellCode(_read(_script));
  final iss = _read(_iss);
  final doc = _read(_doc);

  test('the identifier is the one doc 11 records, AppPublisher.AppName', () {
    final identifier = _constant(code, 'PackageIdentifier');
    expect(identifier, 'poli0981.MarkLens');
    expect(_row(doc, 'PackageIdentifier'), identifier);
    expect(
      identifier,
      '${_define(iss, 'AppPublisher')}.${_define(iss, 'AppName')}',
      reason:
          'The identifier names the winget-pkgs folder for good; it is built '
          'from the publisher and product the installer states.',
    );
  });

  test('the product code is the AppId, as Inno names the uninstall key', () {
    // WinGet finds an installed copy by this key - including one installed
    // from the releases page rather than by WinGet.
    final appId = RegExp(
      r'^AppId=\{(\{[0-9A-F-]{36}\})$',
      multiLine: true,
    ).firstMatch(iss)?.group(1);
    expect(appId, isNotNull, reason: 'No AppId={{GUID} in $_iss.');
    expect(_constant(code, 'ProductCode'), '${appId}_is1');
    expect(_row(doc, 'ProductCode'), '${appId}_is1');
  });

  test('publisher and name are what the installed-apps list shows', () {
    // WinGet matches an installed copy by publisher and name as well as by
    // product code, and the name must not carry a version that changes.
    expect(_constant(code, 'Publisher'), _define(iss, 'AppPublisher'));
    expect(_constant(code, 'PackageName'), _define(iss, 'AppName'));
    expect(
      _directive(iss, 'UninstallDisplayName'),
      '{#AppName}',
      reason:
          "Inno's default display name includes the version, which would make "
          'every release a different name in the installed-apps list.',
    );
  });

  test('the licence is the one the binaries state', () {
    // Komac writes GitHub's detection, GPL-3.0, which is deprecated and says
    // nothing about "only"; the script puts this back.
    expect(_constant(code, 'License'), 'GPL-3.0-only');
    expect(_row(doc, 'License'), 'GPL-3.0-only');
    expect(
      _read(_metainfo),
      contains('<project_license>GPL-3.0-only</project_license>'),
    );
  });

  test('it lists the installer doc 11 names, and never the portable zip', () {
    expect(code, contains(r'MarkLens-Setup-$Version.exe'));
    expect(doc, contains('`MarkLens-Setup-x.y.z.exe`'));
    expect(
      code,
      isNot(contains('portable')),
      reason:
          'The zip has no AppId: WinGet could not recognise it, and the update '
          'banner would lead from it to a second copy.',
    );
  });

  test('the runtime dependency and the scope are the ones doc 11 records', () {
    expect(_constant(code, 'Dependency'), 'Microsoft.VCRedist.2015+.x64');
    expect(_row(doc, 'Dependencies'), _constant(code, 'Dependency'));
    expect(_row(doc, 'Scope'), 'user');
    expect(code, contains(r'Scope:\s*machine|/ALLUSERS|ElevationRequirement'));
  });

  test('it refuses what WinGet must never pin', () {
    // A draft's assets are a 404 to everyone else; a prerelease is ignored by
    // UpdateService and so by this; an installer that is not the one
    // release.yml hashed is not the one this repository built; and a second
    // pull request for one version is noise a reviewer has to close.
    expect(code, contains('isDraft'));
    expect(code, contains('isPrerelease'));
    expect(code, contains('SHA256SUMS'));
    expect(code, contains('gh pr list --repo microsoft/winget-pkgs'));
  });

  test(
    "Komac is pinned by version and digest, and the version is doc 11's",
    () {
      final pin = RegExp(
        r'^\| Komac \| `([\d.]+)` \|',
        multiLine: true,
      ).firstMatch(doc)?.group(1);
      expect(pin, isNotNull, reason: "No Komac row in doc 11's pin table.");
      expect(_constant(code, 'KomacVersion'), pin);
      expect(
        _constant(code, 'KomacSha256'),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    },
  );

  test('Komac is verified before it runs', () {
    final verify = code.indexOf(r'Get-FileHash -Algorithm SHA256 $komac');
    expect(verify, isNonNegative, reason: 'No hash check of $_script Komac.');
    for (final use in <String>[r'& $komac update', r'& $komac submit']) {
      final at = code.indexOf(use);
      expect(at, isNonNegative, reason: 'No "$use" in $_script.');
      expect(verify, lessThan(at), reason: 'The hash is checked after "$use".');
    }
  });

  test('generating is a dry run, and submitting is asked for', () {
    expect(code, matches(RegExp(r'& \$komac update[^\n]*--dry-run')));
    expect(
      RegExp(r'& \$komac submit').allMatches(code),
      hasLength(1),
      reason: 'One place submits, and only behind -Submit.',
    );
    expect(code, matches(RegExp(r'if \(\$Submit\) \{\s*& \$komac submit')));
  });

  test('the token is never a parameter and does not outlive the run', () {
    final param = RegExp(r'param\(([\s\S]*?)\n\)').firstMatch(code)?.group(1);
    expect(param, isNotNull, reason: 'No param() block in $_script.');
    expect(param!.toLowerCase(), isNot(contains('token')));
    expect(code, contains('gh auth token'));
    expect(code, contains('finally'));
    expect(code, contains('Env:GITHUB_TOKEN'));
    expect(
      code,
      isNot(contains('komac token')),
      reason: 'Komac can store a token; this script must never ask it to.',
    );
  });
}
