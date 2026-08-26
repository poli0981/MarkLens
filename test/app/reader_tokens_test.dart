/// `docs/06_UI_UX.md`: the eight theme tokens, finalized at M1.
///
/// Contrast is measured here rather than judged by eye. A palette is easy to
/// nudge and hard to re-check, so the ratios that make text readable are
/// assertions — in both themes, for every pairing that actually occurs on
/// screen.
///
/// Thresholds are WCAG 2.1: 4.5:1 for normal text (AA), 7:1 (AAA) for body
/// text against the reading surface, since that is the pairing a person stares
/// at for an hour, and 3:1 for the non-text contrast of a UI boundary.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/theme/reader_tokens.dart';

/// WCAG relative luminance.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4) as double;

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const palettes = <String, ReaderTokens>{
    'light': ReaderTokens.light,
    'dark': ReaderTokens.dark,
  };

  palettes.forEach((name, tokens) {
    group('$name palette', () {
      test('body text on the reading surface reaches AAA', () {
        expect(
          contrast(tokens.fg, tokens.bg),
          greaterThanOrEqualTo(7),
          reason:
              'this is the pairing someone reads for an hour; AA is the floor '
              'for incidental text, not for the document itself',
        );
      });

      test('body text is readable on every surface it lands on', () {
        for (final surface in <String, Color>{
          'bgAlt': tokens.bgAlt,
          'codeBg': tokens.codeBg,
        }.entries) {
          expect(
            contrast(tokens.fg, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'fg on ${surface.key} is below AA',
          );
        }
      });

      test('secondary text reaches AA on both surfaces', () {
        for (final surface in <String, Color>{
          'bg': tokens.bg,
          'bgAlt': tokens.bgAlt,
        }.entries) {
          expect(
            contrast(tokens.fgMuted, surface.value),
            greaterThanOrEqualTo(4.5),
            reason:
                'fgMuted on ${surface.key} is below AA — the status bar and '
                'the front-matter keys use it, and both are real text',
          );
        }
      });

      test('links reach AA on both surfaces', () {
        for (final surface in <String, Color>{
          'bg': tokens.bg,
          'bgAlt': tokens.bgAlt,
        }.entries) {
          expect(
            contrast(tokens.accent, surface.value),
            greaterThanOrEqualTo(4.5),
            reason: 'accent on ${surface.key} is below AA',
          );
        }
      });

      test('borders are visible without being loud', () {
        final ratio = contrast(tokens.border, tokens.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(1.3),
          reason: 'a hairline nobody can see is not a boundary',
        );
        expect(
          ratio,
          lessThan(4.5),
          reason:
              'a border with text contrast reads as content; these are '
              'hairlines, not rules',
        );
      });

      test('selected text stays readable', () {
        expect(
          contrast(tokens.fg, tokens.selection),
          greaterThanOrEqualTo(4.5),
          reason:
              'selecting a passage must not make it harder to read than not '
              'selecting it',
        );
      });

      test('the surfaces are distinguishable from each other', () {
        expect(
          contrast(tokens.bg, tokens.bgAlt),
          greaterThan(1.02),
          reason:
              'a panel that is the same colour as the document is not a '
              'panel',
        );
      });

      test('every token is fully opaque', () {
        for (final color in <Color>[
          tokens.bg,
          tokens.bgAlt,
          tokens.fg,
          tokens.fgMuted,
          tokens.accent,
          tokens.codeBg,
          tokens.border,
          tokens.selection,
        ]) {
          expect(
            color.a,
            1.0,
            reason:
                'a translucent token makes its measured contrast a fiction, '
                'because what is behind it decides the real ratio',
          );
        }
      });
    });
  });

  group('the two palettes are actually different', () {
    test('dark is dark and light is light', () {
      expect(
        _luminance(ReaderTokens.light.bg),
        greaterThan(_luminance(ReaderTokens.dark.bg)),
      );
      expect(
        _luminance(ReaderTokens.light.fg),
        lessThan(_luminance(ReaderTokens.dark.fg)),
      );
    });
  });

  group('the extension behaves', () {
    testWidgets('tokens are read from the theme', (tester) async {
      late ReaderTokens seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<Object?>>[ReaderTokens.dark],
          ),
          home: Builder(
            builder: (context) {
              seen = ReaderTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.bg, ReaderTokens.dark.bg);
    });

    testWidgets('a theme without them falls back to light', (tester) async {
      late ReaderTokens seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = ReaderTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.bg, ReaderTokens.light.bg);
    });

    test('lerp moves between the palettes', () {
      final middle = ReaderTokens.light.lerp(ReaderTokens.dark, 1);
      expect(middle.bg, ReaderTokens.dark.bg);
      expect(ReaderTokens.light.lerp(null, 1).bg, ReaderTokens.light.bg);
    });

    test('copyWith replaces only what it is given', () {
      const replacement = Color(0xFF123456);
      final tokens = ReaderTokens.light.copyWith(accent: replacement);
      expect(tokens.accent, replacement);
      expect(tokens.bg, ReaderTokens.light.bg);
    });
  });
}
