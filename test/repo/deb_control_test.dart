/// The Debian package, checked from Windows.
///
/// `dpkg-deb` cannot run here and the package is built in the `tool/linux`
/// container, so this asserts the things that would otherwise only be
/// discovered by installing: that the control file is well formed, that every
/// path the build script copies actually exists, and that removing the package
/// does not remove the user's session.
///
/// The most valuable one is the last. A `.deb` that quietly ships without its
/// icons, or that deletes `settings.json` on `apt remove`, produces no error at
/// build time and no error at install time.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _debian = 'packaging/linux/deb/DEBIAN';
const String _script = 'packaging/linux/build-deb.sh';

String _read(String relative) {
  final file = File(relative);
  if (!file.existsSync()) {
    throw StateError('$relative is missing.');
  }
  return file.readAsStringSync();
}

/// A shell script with its whole-line comments removed.
///
/// Same trade-off `test/architecture/source_scan.dart` documents: trailing
/// comments are left alone, because dropping everything after a `#` would also
/// eat one inside a string. A false positive here is cheap; a false negative
/// is a test that passes while `postrm` deletes somebody's session.
String _shellCode(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

/// A `Field: value` line from a Debian control stanza.
String? _field(String control, String name) => RegExp(
  '^$name:[ \t]*(.*)\$',
  multiLine: true,
).firstMatch(control)?.group(1)?.trim();

void main() {
  final control = _read('$_debian/control.in');
  final script = _read(_script);

  group('the control stanza', () {
    test('carries the fields dpkg requires', () {
      // dpkg-deb refuses to build without these, but it refuses in the
      // container, which is a slower place to find out than here.
      for (final field in <String>[
        'Package',
        'Version',
        'Architecture',
        'Maintainer',
        'Description',
      ]) {
        expect(
          _field(control, field),
          isNotNull,
          reason: '$field is mandatory in a Debian control file.',
        );
      }
      expect(_field(control, 'Package'), 'marklens');
      expect(_field(control, 'Architecture'), 'amd64');
    });

    test('leaves the build-time values as placeholders', () {
      // A literal version here would be a fifth copy of a number that already
      // lives in pubspec.yaml, version.dart, the git tag and the .iss. A
      // literal Installed-Size would simply be wrong.
      for (final field in <String>[
        'Version',
        'Depends',
        'Installed-Size',
        'Maintainer',
      ]) {
        expect(
          _field(control, field),
          matches(RegExp(r'^@\w+@$')),
          reason:
              '$field must stay a @PLACEHOLDER@ - build-deb.sh substitutes it.',
        );
      }
    });

    test('the description is in the format dpkg parses', () {
      // Debian's format is unusual and unforgiving: a one-line synopsis, then
      // continuation lines that each start with a single space, and a lone " ."
      // for a paragraph break. A flush-left line silently ends the field.
      final lines = control.split('\n');
      final start = lines.indexWhere((l) => l.startsWith('Description:'));
      expect(start, isNot(-1));

      final body = lines.skip(start + 1).takeWhile((l) => l.startsWith(' '));
      expect(
        body,
        isNotEmpty,
        reason: 'The synopsis has no extended description below it.',
      );
      expect(
        body.where((l) => l.trim().isEmpty),
        isEmpty,
        reason:
            'A truly blank continuation line ends the field. Debian writes a '
            'paragraph break as a line containing exactly " .".',
      );
    });
  });

  group('the maintainer scripts', () {
    test('are shell, and stop on error', () {
      for (final name in <String>['postinst', 'prerm', 'postrm']) {
        final body = _read('$_debian/$name');
        expect(
          body,
          startsWith('#!/bin/sh\n'),
          reason: '$name needs a shebang; dpkg execs it directly.',
        );
        expect(
          body,
          contains('\nset -e\n'),
          reason:
              '$name should abort on an unexpected failure rather than '
              'continue and report success.',
        );
      }
    });

    test('are installed executable', () {
      // The mode in the archive comes from `install -m 755` in the build
      // script, not from the checkout - a Windows working tree has no execute
      // bit to preserve, so asserting one here would test the wrong thing.
      expect(
        script,
        contains('install -m 755'),
        reason:
            'A maintainer script without the execute bit makes dpkg fail the '
            'install, after the files have already been unpacked.',
      );
    });

    test('removal leaves the user session alone', () {
      // The one destructive thing a package manager could do here. session.json
      // and settings.json are the user's, not the package's (doc 05), and
      // `apt remove` of a viewer should not lose somebody's tabs.
      final postrm = _shellCode(_read('$_debian/postrm'));
      for (final destructive in <String>[
        'rm -rf',
        'rm -r ',
        'XDG_DATA_HOME',
        '.local/share',
      ]) {
        expect(
          postrm,
          isNot(contains(destructive)),
          reason:
              'postrm must not reach into the user config directory. Found '
              '"$destructive" in executable lines, not just in a comment.',
        );
      }
    });

    test('the caches that decide visibility are refreshed', () {
      // Each of these is the difference between "installed" and "visible":
      // the desktop database indexes MimeType=, the mime database may not know
      // text/markdown at all on the 22.04 floor, and the icon cache is what
      // makes GNOME show the icon rather than a generic one.
      final postinst = _read('$_debian/postinst');
      for (final command in <String>[
        'update-desktop-database',
        'update-mime-database',
        'gtk-update-icon-cache',
      ]) {
        expect(postinst, contains(command));
      }
    });
  });

  group('the build script', () {
    test('every file it installs exists', () {
      for (final path in <String>[
        'packaging/linux/dev.poli0981.marklens.desktop',
        'packaging/linux/marklens-mime.xml',
        'packaging/linux/icons/hicolor/48x48/apps/marklens.png',
        'packaging/linux/dev.poli0981.marklens.metainfo.xml',
        'LICENSE',
        '$_debian/control.in',
        '$_debian/postinst',
        '$_debian/prerm',
        '$_debian/postrm',
      ]) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              '$path is referenced by build-deb.sh and is not in the tree. The '
              'script would fail in the container, which is a slow place to '
              'learn it.',
        );
      }
    });

    test('the bundle keeps its lib/ beside the binary', () {
      // CMAKE_INSTALL_RPATH is $ORIGIN/lib, so copying only the executable to
      // /usr/bin gives a program that installs cleanly and then refuses to
      // start. The bundle goes to /usr/lib/marklens and /usr/bin is a symlink.
      expect(script, contains('usr/lib/marklens'));
      expect(
        script,
        contains('ln -s ../lib/marklens/marklens'),
        reason:
            'A relative symlink, so the package does not depend on being '
            'installed at the root it was built for.',
      );
    });

    test('it derives Depends rather than guessing them', () {
      // A hand-written Depends is a list somebody has to remember to update
      // when a plugin adds a library. dpkg-shlibdeps reads what the binary
      // actually needs.
      expect(script, contains('dpkg-shlibdeps'));
      expect(
        script,
        contains('refusing to ship a package'),
        reason:
            'An empty Depends is worse than a wrong one: it installs anywhere '
            'and fails at launch.',
      );
    });

    test('it strips the build metadata from the version', () {
      // `1.0.0+1` is a valid pubspec version and an invalid Debian one.
      expect(script, contains(r'[0-9]\+\.[0-9]\+\.[0-9]\+'));
    });

    test('it ships the AppStream metadata a software centre reads', () {
      // GNOME Software and KDE Discover show this and nothing else; without it
      // the package installs and then appears as a bare binary name. It is the
      // Linux counterpart of the Windows version block rather than paperwork,
      // and appimagetool warns when it is absent.
      expect(script, contains('usr/share/metainfo'));
      final metainfo = _read(
        'packaging/linux/dev.poli0981.marklens.metainfo.xml',
      );
      expect(metainfo, contains('<id>dev.poli0981.marklens</id>'));
      expect(
        metainfo,
        contains('<project_license>GPL-3.0-only</project_license>'),
      );
      expect(
        metainfo,
        contains('type="desktop-id">dev.poli0981.marklens.desktop<'),
        reason:
            'The launchable has to name the desktop entry the package actually '
            'installs, or the software centre shows no Launch button.',
      );
    });

    test('the desktop entry declares one main category', () {
      // desktop-file-validate found this twice. Two main categories can list
      // the application twice in a menu; pairing TextEditor with Utility, which
      // the spec wants, would fix that by asserting MarkLens edits text.
      final categories = RegExp(r'^Categories=(.*)$', multiLine: true)
          .firstMatch(_read('packaging/linux/dev.poli0981.marklens.desktop'))
          ?.group(1);
      expect(categories, 'Office;Viewer;');
    });

    test('it emits the filename doc 11 names', () {
      expect(script, contains(r'marklens_${version}_amd64.deb'));
      expect(
        _read('docs/11_PACKAGING_UPDATE.md'),
        contains('`marklens_x.y.z_amd64.deb`'),
      );
    });
  });
}
