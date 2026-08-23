import 'package:flutter/painting.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:marklens/features/reader/rendering/code_highlighter.dart';

/// [CodeHighlighter] backed by the pure-Dart `highlight` package — the S1c
/// winner (`docs/spike-results/S1c-highlighter.md`).
///
/// Note it uses `highlight`, **not** `flutter_highlight`. The widget wrapper is
/// exactly the part MarkLens does not need: this seam returns spans, not a
/// widget, and the wrapper's only other contribution was 90 bundled themes we
/// would rather derive from our own doc 06 tokens (doc 13: prefer fifty lines
/// of our own code over a utility dependency).
class HighlightJsCodeHighlighter implements CodeHighlighter {
  /// Creates a highlighter that paints scopes using [theme].
  const HighlightJsCodeHighlighter({required this.theme, this.baseStyle});

  /// Maps a highlight.js scope name (`keyword`, `string`, `comment`, …) to the
  /// style it should paint with. Scopes absent from the map render as
  /// [baseStyle], which is what keeps an unfamiliar grammar readable rather
  /// than invisible.
  final Map<String, TextStyle> theme;

  /// Style for text carrying no scope.
  final TextStyle? baseStyle;

  @override
  List<InlineSpan> spans({required String code, String? language}) {
    // No language means no guess. highlight.js can auto-detect, but a wrong
    // guess colours a document misleadingly and the detection is not cheap;
    // an unlabelled fence renders plain, as docs/04 expects.
    if (language == null || language.isEmpty) {
      return <InlineSpan>[TextSpan(text: code, style: baseStyle)];
    }

    try {
      final result = hl.highlight.parse(code, language: language);
      final spans = <InlineSpan>[];
      _emit(result.nodes, spans, baseStyle);
      // An empty result would silently swallow the block, so fall back rather
      // than render nothing.
      return spans.isEmpty
          ? <InlineSpan>[TextSpan(text: code, style: baseStyle)]
          : spans;
    } on Object {
      // CLAUDE.md rule 9: document content never crashes the app. An unknown
      // language already degrades quietly inside `parse` — verified in S1c —
      // but a grammar bug must not become a crash either.
      return <InlineSpan>[TextSpan(text: code, style: baseStyle)];
    }
  }

  void _emit(List<hl.Node>? nodes, List<InlineSpan> out, TextStyle? inherited) {
    for (final node in nodes ?? const <hl.Node>[]) {
      final style = node.className == null
          ? inherited
          : theme[node.className] ?? inherited;

      if (node.value != null) {
        out.add(TextSpan(text: node.value, style: style));
      }
      if (node.children != null) {
        _emit(node.children, out, style);
      }
    }
  }
}
