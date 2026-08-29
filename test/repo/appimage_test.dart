/// The AppImage build, and the two downloads inside it.
///
/// An AppImage is assembled by a tool that is itself downloaded, and that tool
/// then downloads a *runtime* and welds it into the artefact users run. Both
/// happen inside the one workflow that will hold `contents: write`, which makes
/// this the sharpest supply-chain surface in the repo — and the second download
/// is invisible unless you read the build log, because appimagetool does it
/// without being asked.
///
/// So most of what this file checks is that neither fetch can move: pinned by
/// tag, verified by SHA-256 *before* being executed, and never from a
/// `continuous` tag, which is a different file from one week to the next.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _script = 'packaging/linux/build-appimage.sh';
const String _appRun = 'packaging/linux/AppRun';

String _read(String relative) {
  final file = File(relative);
  if (!file.existsSync()) {
    throw StateError('$relative is missing.');
  }
  return file.readAsStringSync();
}

/// A shell script with its whole-line comments removed, so prose about a
/// mistake cannot be mistaken for the mistake.
String _shellCode(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

void main() {
  final script = _read(_script);
  final code = _shellCode(script);
  final appRun = _shellCode(_read(_appRun));

  group('the downloads', () {
    test('both are pinned by tag and by digest', () {
      for (final pin in <String>[
        'APPIMAGETOOL_TAG',
        'APPIMAGETOOL_SHA256',
        'APPIMAGE_RUNTIME_TAG',
        'APPIMAGE_RUNTIME_SHA256',
      ]) {
        expect(
          RegExp('^$pin="[^"]+"\$', multiLine: true).hasMatch(code),
          isTrue,
          reason: '$pin is not set to a literal in build-appimage.sh.',
        );
      }
      expect(
        RegExp('SHA256="[0-9a-f]{64}"').allMatches(code),
        hasLength(2),
        reason: 'Both digests must be full 64-character SHA-256 hex.',
      );
    });

    test('nothing comes from a moving tag', () {
      // `continuous` is what appimagetool reaches for by default, and it is a
      // different binary from week to week. A release built twice from the same
      // commit would not be the same file.
      expect(
        code,
        isNot(contains('/continuous/')),
        reason:
            'A continuous tag makes the artefact unreproducible and '
            'unauditable at the same time.',
      );
    });

    test('the digest is checked before the binary is run', () {
      // Verifying afterwards would mean having already executed it.
      final verify = code.indexOf('sha256sum');
      final execute = code.indexOf(r'"$tool"');
      expect(verify, isNot(-1));
      expect(execute, isNot(-1));
      expect(
        verify,
        lessThan(execute),
        reason:
            'build-appimage.sh executes appimagetool before verifying it. The '
            'check has to come first or it is not a check.',
      );
      expect(code, contains('exit 1'));
    });

    test('the runtime is handed to appimagetool explicitly', () {
      // Without --runtime-file, appimagetool downloads one itself and the pin
      // above is decoration.
      expect(code, contains('--runtime-file'));
    });

    test('it can build without FUSE', () {
      // appimagetool is an AppImage and mounts itself to run. Neither a
      // container nor a GitHub runner provides FUSE.
      expect(code, contains('APPIMAGE_EXTRACT_AND_RUN=1'));
    });
  });

  group('AppRun', () {
    test('replaces itself rather than lingering as a parent shell', () {
      expect(
        appRun,
        contains(r'exec "$HERE/usr/bin/marklens" "$@"'),
        reason:
            'Without exec, a shell stays alive as the parent of the '
            'application for the whole session, and every argument has to be '
            'forwarded by hand.',
      );
    });

    test('does not put the bundled libraries on the global search path', () {
      // The bundle finds its own libraries through $ORIGIN/lib. Setting
      // LD_LIBRARY_PATH would put our copies ahead of the host's for every
      // child process too, which is the classic way an AppImage breaks the
      // file dialog it just opened.
      expect(appRun, isNot(contains('LD_LIBRARY_PATH')));
    });

    test('works from an extracted directory as well as a mounted one', () {
      // --appimage-extract leaves a plain directory with no $APPDIR set, and
      // that is how the build verifies the artefact on a machine without FUSE.
      expect(appRun, contains(r'${APPDIR:-'));
    });
  });

  group('the AppDir', () {
    test('carries what appimagetool requires at its root', () {
      // A desktop entry and an icon at the root, or the build fails; the icon
      // has to match the entry's Icon= name or the AppImage has no thumbnail.
      expect(script, contains(r'"$appdir/dev.poli0981.marklens.desktop"'));
      expect(script, contains(r'"$appdir/marklens.png"'));
      expect(
        _read('packaging/linux/dev.poli0981.marklens.desktop'),
        contains('Icon=marklens'),
      );
    });

    test('has the same shape as the installed .deb', () {
      // One filesystem layout for both artefacts, so the AppRun path and the
      // /usr/bin symlink are the same relative walk and a bug in one is a bug
      // in both rather than a bug in whichever was tested less.
      expect(script, contains('ln -s ../lib/marklens/marklens'));
      expect(script, contains(r'"$appdir/usr/lib/marklens/"'));
      expect(script, contains('usr/share/metainfo'));
    });

    test('it emits the filename doc 11 names', () {
      expect(script, contains(r'MarkLens-${version}-x86_64.AppImage'));
      expect(
        _read('docs/11_PACKAGING_UPDATE.md'),
        contains('`MarkLens-x.y.z-x86_64.AppImage`'),
      );
    });
  });
}
