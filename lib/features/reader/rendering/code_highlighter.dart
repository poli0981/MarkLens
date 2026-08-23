import 'package:flutter/painting.dart';

/// Colours a fenced code block.
///
/// Kept behind an interface because the engine is the most replaceable thing
/// in the reader: `highlight 0.7.0` won S1c on measurement, but it has not
/// shipped in five years and comes from an unverified uploader
/// (`docs/spike-results/S1c-highlighter.md`). Swapping it should touch one
/// file — `highlight_js_code_highlighter.dart` — and nothing else.
abstract class CodeHighlighter {
  /// Returns the spans for [code], highlighted for [language].
  ///
  /// An unknown or absent [language], or a grammar the implementation does not
  /// have, must yield plain unstyled spans — never an exception, and never an
  /// error message in place of the user's code.
  List<InlineSpan> spans({required String code, String? language});
}
