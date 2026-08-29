/// The program's own name, in the five places no Dart code can reach.
///
/// Nothing in `lib/` sets the native window title: `WindowLink` has no
/// `setTitle`, so what a user sees in the taskbar, in alt-tab and in Explorer's
/// Description column is whatever the C++ runner and the resource script say.
/// Through M3 all of them said `marklens`, because that is the CMake
/// `BINARY_NAME` and the Flutter template reuses it for everything.
///
/// The binary stays `marklens` — `associations.iss` and the `.desktop` `Exec`
/// both name it, and lowercase is right for an executable. The *product* is
/// MarkLens. Those are different strings that the template happened to make
/// equal, and a cross-file text test is the only kind that can hold them apart,
/// because no test that runs the app can observe any of them.
///
/// Text-scanning for the same reason as `pin_agreement_test.dart`: `.rc`, `.cc`
/// and `.desktop` have no parser in this tree, and `package:yaml` is
/// transitive-only so it cannot be imported without failing `flutter analyze`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _desktopEntry = 'packaging/linux/dev.poli0981.marklens.desktop';

String _read(String relative) {
  final file = File(relative);
  expect(file.existsSync(), isTrue, reason: '$relative is missing.');
  return file.readAsStringSync();
}

/// The value of a `VALUE "key", "value"` line in a Windows resource script.
String _rcValue(String rc, String key) {
  final match = RegExp('VALUE\\s+"$key",\\s*"([^"]*)"').firstMatch(rc);
  expect(match, isNotNull, reason: 'Runner.rc has no VALUE "$key".');
  return match!.group(1)!;
}

/// The value of a `Key=value` line in a desktop entry.
String _desktopValue(String entry, String key) {
  final match = RegExp(
    '^${RegExp.escape(key)}=(.*)\$',
    multiLine: true,
  ).firstMatch(entry);
  expect(match, isNotNull, reason: '$_desktopEntry has no $key= line.');
  return match!.group(1)!.trim();
}

/// A `set(NAME "value")` from a CMakeLists.
String _cmakeString(String cmake, String name) {
  final match = RegExp('set\\($name\\s+"([^"]*)"\\)').firstMatch(cmake);
  expect(match, isNotNull, reason: 'CMakeLists has no set($name ...).');
  return match!.group(1)!;
}

void main() {
  group('the product is called MarkLens', () {
    test('the Windows version block says so', () {
      final rc = _read('windows/runner/Runner.rc');
      for (final key in <String>[
        'ProductName',
        'FileDescription',
        'InternalName',
      ]) {
        expect(
          _rcValue(rc, key),
          'MarkLens',
          reason:
              'Runner.rc $key is what Explorer shows in its Description column '
              'and what labels the "Open with" entry. It is the product name, '
              'not the file name.',
        );
      }
    });

    test('both native window titles say so', () {
      expect(
        _read('windows/runner/main.cpp'),
        contains('window.Create(L"MarkLens"'),
        reason: 'The Windows window title is set before Dart exists.',
      );
      expect(
        RegExp(r'set_title\((?:header_bar|window),\s*"([^"]*)"\)')
            .allMatches(_read('linux/runner/my_application.cc'))
            .map((m) => m.group(1))
            .toSet(),
        <String>{'MarkLens'},
        reason:
            'my_application.cc sets the title twice — header bar and window — '
            'and both are user-visible.',
      );
    });

    test('the desktop entry says so', () {
      expect(_desktopValue(_read(_desktopEntry), 'Name'), 'MarkLens');
    });
  });

  test('the copyright line does not claim rights this licence gives away', () {
    // "All rights reserved" is the Flutter template's, and on a GPL-3.0-only
    // binary it is a false licence statement sitting inside the exe's own
    // metadata — somewhere no reader of LICENSE will ever look.
    final copyright = _rcValue(
      _read('windows/runner/Runner.rc'),
      'LegalCopyright',
    );
    expect(copyright, contains('GPL-3.0-only'));
    expect(copyright.toLowerCase(), isNot(contains('all rights reserved')));
  });

  test('the binary is still lowercase marklens everywhere it is named', () {
    // Renaming the product must not rename the executable: the Inno script and
    // the desktop Exec both hard-code it, and neither is Dart.
    expect(
      _cmakeString(_read('windows/CMakeLists.txt'), 'BINARY_NAME'),
      'marklens',
    );
    expect(
      _cmakeString(_read('linux/CMakeLists.txt'), 'BINARY_NAME'),
      'marklens',
    );
    expect(
      _rcValue(_read('windows/runner/Runner.rc'), 'OriginalFilename'),
      'marklens.exe',
    );
    expect(_desktopValue(_read(_desktopEntry), 'Exec'), 'marklens %F');
    expect(
      _read('packaging/windows/associations.iss'),
      contains(r'{app}\marklens.exe'),
    );
  });

  group('the desktop entry agrees with the application it describes', () {
    test('StartupWMClass is the application id GTK actually advertises', () {
      // my_application.cc calls g_set_prgname(APPLICATION_ID), and GTK derives
      // WM_CLASS res_name and the Wayland app_id from g_get_prgname(). The
      // template's StartupWMClass=marklens therefore matched nothing, and the
      // symptom is a second generic taskbar entry rather than an error.
      final applicationId = _cmakeString(
        _read('linux/CMakeLists.txt'),
        'APPLICATION_ID',
      );
      expect(
        _read('linux/runner/my_application.cc'),
        contains('g_set_prgname(APPLICATION_ID)'),
        reason:
            'If the runner stops setting prgname from APPLICATION_ID, the WM '
            'class this test pins is no longer the one GTK reports.',
      );
      expect(
        _desktopValue(_read(_desktopEntry), 'StartupWMClass'),
        applicationId,
      );
      expect(
        _desktopEntry.split('/').last,
        '$applicationId.desktop',
        reason:
            'The desktop-file-id should equal the application id, which is '
            'what makes StartupWMClass redundant on Wayland rather than merely '
            'correct.',
      );
    });

    test('its translated strings are the ones the app ships', () {
      // The .desktop lands in the applications menu, so Comment and GenericName
      // are user-facing strings in the sense of CLAUDE.md rule 4 — but they
      // cannot be ARB keys, because nothing Dart renders them. Copying is the
      // only option; copying without a check is how the two drift.
      final entry = _read(_desktopEntry);
      const arbFiles = <String, String>{
        'vi': 'app_vi',
        'ja': 'app_ja',
      };
      for (final locale in arbFiles.entries) {
        final arb = jsonDecode(
          _read('lib/l10n/${locale.value}.arb'),
        ) as Map<String, dynamic>;
        final tagline = (arb['aboutTagline']! as String).replaceAll(
          RegExp(r'[.。]$'),
          '',
        );
        expect(
          _desktopValue(entry, 'Comment[${locale.key}]'),
          tagline,
          reason:
              'Comment[${locale.key}] should be aboutTagline from '
              '${locale.value}.arb, so About and the applications menu cannot '
              'describe this program differently.',
        );
      }
    });
  });
}
