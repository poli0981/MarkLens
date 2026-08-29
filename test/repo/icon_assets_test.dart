/// The icon set, which is nine PNGs, an SVG and an ICO that nobody opens.
///
/// `windows/runner/resources/app_icon.ico` was byte-identical to the Flutter
/// template's default from M0 to M4 and no review caught it, because a binary
/// asset is invisible in a diff. The same blindness applies to every file here:
/// a missing hicolor size, a PNG in the wrong directory, or a set that quietly
/// lost its transparency would all look exactly like nothing.
///
/// So this reads the bytes. PNG and ICO headers are a few `struct` reads, which
/// is cheaper than a dependency and, per doc 13, preferable to one.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The sizes `tool/icons/render_icon.py` emits. Adding one means adding it in
/// both places, which is the point.
const List<int> _hicolorSizes = <int>[16, 24, 32, 48, 64, 96, 128, 256, 512];
const List<int> _icoSizes = <int>[16, 24, 32, 48, 64, 96, 128, 256];

/// The byte length of the Flutter template's `app_icon.ico`, recorded at M4
/// before it was replaced. A literal because the template file is not in this
/// repo to compare against — it lives in the pub cache, which CI resolves
/// fresh. Length alone is a weak fingerprint, and it does not have to be
/// strong: the structural test above already rejects the template's shape (ten
/// entries, four of them 4- and 8-bpp BMP), so this only has to catch the one
/// case where someone restores that exact file.
const int _templateIcoBytes = 33772;

const String _hicolor = 'packaging/linux/icons/hicolor';
const String _ico = 'windows/runner/resources/app_icon.ico';

Uint8List _bytes(String relative) {
  final file = File(relative);
  expect(file.existsSync(), isTrue, reason: '$relative is missing.');
  return file.readAsBytesSync();
}

/// `(width, height)` from a PNG's IHDR, which is always the first chunk.
(int, int) _pngSize(Uint8List png, String where) {
  expect(
    png.sublist(0, 8),
    <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    reason: '$where does not start with the PNG signature.',
  );
  final header = ByteData.sublistView(png);
  return (header.getUint32(16), header.getUint32(20));
}

/// The colour type byte from a PNG's IHDR. 6 is RGBA, which is the only one
/// that can carry the transparency an application icon needs.
int _pngColourType(Uint8List png) => png[25];

void main() {
  group('the hicolor set', () {
    test('every size exists, in the directory that names it', () {
      for (final size in _hicolorSizes) {
        final path = '$_hicolor/${size}x$size/apps/marklens.png';
        final (width, height) = _pngSize(_bytes(path), path);
        expect(
          <int>[width, height],
          <int>[size, size],
          reason:
              '$path is ${width}x$height. A PNG in the wrong hicolor directory '
              'is not an error anywhere - the desktop just picks the wrong one '
              'and scales it.',
        );
      }
    });

    test('the corners are transparent, not black', () {
      // The maintainer's original export was flattened onto opaque black at
      // every size, which renders as a black tile on any light background. A
      // colour-type check catches the whole class: an icon without an alpha
      // channel has no way to not have a background.
      for (final size in _hicolorSizes) {
        final path = '$_hicolor/${size}x$size/apps/marklens.png';
        expect(
          _pngColourType(_bytes(path)),
          6,
          reason:
              '$path is not RGBA, so whatever surrounds the shape is opaque. '
              'Regenerate with tool/icons/render_icon.py.',
        );
      }
    });

    test('the scalable copy is the master, byte for byte', () {
      expect(
        _bytes('$_hicolor/scalable/apps/marklens.svg'),
        _bytes('icon/marklens.svg'),
        reason:
            'hicolor scalable/ and icon/marklens.svg are both written by '
            'render_icon.py in the same run; if they differ, one was edited by '
            'hand and the next run will silently revert it.',
      );
    });
  });

  group('the Windows icon', () {
    test('is a multi-size, all-PNG, 32-bpp ICO', () {
      final ico = _bytes(_ico);
      final directory = ByteData.sublistView(ico);
      expect(directory.getUint16(0, Endian.little), 0, reason: 'reserved');
      expect(directory.getUint16(2, Endian.little), 1, reason: 'type = icon');
      expect(directory.getUint16(4, Endian.little), _icoSizes.length);

      for (var i = 0; i < _icoSizes.length; i++) {
        final entry = 6 + i * 16;
        // A directory entry stores 256 as 0; nothing larger is expressible.
        final declared = ico[entry] == 0 ? 256 : ico[entry];
        expect(declared, _icoSizes[i]);
        expect(
          directory.getUint16(entry + 6, Endian.little),
          32,
          reason: 'Frame $declared is not 32-bpp, so it has no alpha channel.',
        );

        final offset = directory.getUint32(entry + 12, Endian.little);
        final frame = Uint8List.sublistView(ico, offset);
        final (width, height) = _pngSize(frame, '$_ico frame $declared');
        expect(<int>[width, height], <int>[declared, declared]);
      }
    });

    test('is no longer the Flutter template default', () {
      // It was, from M0 to M4 - the same 33,772 bytes the template ships,
      // which associations.iss would have registered as the icon for every .md
      // file on the machine. Nothing failed; it just quietly was not this
      // program's brand, and no diff could show it.
      expect(
        _bytes(_ico).length,
        isNot(_templateIcoBytes),
        reason:
            'app_icon.ico is the size of the Flutter template default. Run '
            'tool/icons/render_icon.py.',
      );
    });
  });

  test('the desktop entry asks for an icon this set provides', () {
    // Icon=marklens is a *name*, resolved against the hicolor theme, so a
    // mismatch produces a missing icon rather than an error at install time.
    final entry = File('packaging/linux/dev.poli0981.marklens.desktop')
        .readAsStringSync();
    final icon = RegExp(
      r'^Icon=(.*)$',
      multiLine: true,
    ).firstMatch(entry)?.group(1);
    expect(icon, 'marklens');
    expect(
      File('$_hicolor/48x48/apps/$icon.png').existsSync(),
      isTrue,
      reason: 'Icon=$icon does not resolve to a file in the shipped set.',
    );
  });
}
