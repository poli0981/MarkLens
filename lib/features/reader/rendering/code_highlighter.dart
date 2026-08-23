import 'package:flutter/painting.dart';

/// Colours a fenced code block.
///
/// Kept behind an interface because the pin is provisional: the incumbent
/// `flutter_highlight` has not shipped in five years, and spike S1 chooses
/// between it, `re_highlight` and `syntax_highlight`
/// (`docs/01_TECH_STACK.md`). Replacing it should touch one file.
abstract class CodeHighlighter {
  /// Returns the spans for [code], highlighted for [language].
  ///
  /// An unknown or absent [language], or a grammar the implementation does not
  /// have, must yield plain unstyled spans — never an exception, and never an
  /// error message in place of the user's code.
  List<InlineSpan> spans({required String code, String? language});
}
