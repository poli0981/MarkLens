import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/features/reader/rendering/highlight_js_code_highlighter.dart';

/// The `CodeHighlighter` contract from `docs/spike-results/S1c-highlighter.md`:
/// colour what it knows, pass through what it does not, and never throw on
/// document content (CLAUDE.md rule 9).
void main() {
  const keyword = TextStyle(fontWeight: FontWeight.bold);
  const string = TextStyle(fontStyle: FontStyle.italic);
  const base = TextStyle(fontSize: 14);

  const highlighter = HighlightJsCodeHighlighter(
    theme: <String, TextStyle>{'keyword': keyword, 'string': string},
    baseStyle: base,
  );

  /// Concatenates the text of [spans], so tests can assert nothing was lost.
  String textOf(List<InlineSpan> spans) =>
      spans.map((s) => s is TextSpan ? s.text ?? '' : '').join();

  group('highlighting a known language', () {
    const dart = "const greeting = 'xin chào';";

    test('applies the themed styles', () {
      final spans = highlighter.spans(code: dart, language: 'dart');

      expect(spans, isNotEmpty);
      expect(
        spans.whereType<TextSpan>().map((s) => s.style),
        contains(keyword),
        reason: 'const should have been styled as a keyword',
      );
      expect(
        spans.whereType<TextSpan>().map((s) => s.style),
        contains(string),
        reason: 'the string literal should have been styled',
      );
    });

    test('loses no characters', () {
      expect(textOf(highlighter.spans(code: dart, language: 'dart')), dart);
    });

    test('keeps multibyte text intact', () {
      const code = "final s = 'Tiếng Việt 日本語';";
      final spans = highlighter.spans(code: code, language: 'dart');
      expect(textOf(spans), code);
    });

    test('a scope missing from the theme falls back to the base style', () {
      // The theme here knows only keyword and string, so comments must still
      // render — unstyled, never invisible.
      const code = '// một ghi chú\nconst a = 1;';
      final spans = highlighter.spans(code: code, language: 'dart');
      expect(textOf(spans), code);
      expect(spans.whereType<TextSpan>().map((s) => s.style), contains(base));
    });
  });

  group('degrading', () {
    const plain = 'this is not any known language\n  indented line\n';

    test('an unknown language passes the code through unstyled', () {
      final spans = highlighter.spans(code: plain, language: 'zzunknownlang');
      expect(textOf(spans), plain);
      expect(
        spans.whereType<TextSpan>().map((s) => s.style).toSet(),
        <TextStyle?>{base},
        reason: 'nothing should have been coloured',
      );
    });

    test('no language at all renders plain without guessing', () {
      final spans = highlighter.spans(code: plain);
      expect(textOf(spans), plain);
      expect(spans, hasLength(1));
    });

    test('an empty code block is not an error', () {
      expect(textOf(highlighter.spans(code: '', language: 'dart')), isEmpty);
    });

    test('adversarial input does not throw', () {
      // Unterminated string, unbalanced braces, a lone continuation byte's
      // replacement char, and a very long line.
      final nasty = <String>[
        "const s = 'unterminated",
        '{{{{{{{{{{',
        'contains � replacement chars',
        'x' * 20000,
        '\n' * 500,
      ];
      for (final code in nasty) {
        expect(
          () => highlighter.spans(code: code, language: 'dart'),
          returnsNormally,
          reason: 'threw on: ${code.substring(0, code.length.clamp(0, 20))}',
        );
      }
    });
  });
}
