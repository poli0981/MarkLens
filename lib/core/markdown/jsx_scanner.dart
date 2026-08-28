/// Just enough JSX lexing for `MdxSanitizer` — where a tag ends, and where a
/// block-level region closes.
///
/// Deliberately **not** a JSX parser (`docs/04_MARKDOWN_PIPELINE.md`): it has
/// to be simple enough to reason about and impossible to crash, because every
/// `.mdx` file is untrusted input (CLAUDE.md rule 9). Nothing here throws and
/// nothing here recurses — nesting is an integer, so the pathological fixture
/// costs the same as a shallow one.
library;

const int _lessThan = 0x3C;
const int _greaterThan = 0x3E;
const int _slash = 0x2F;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _backslash = 0x5C;
const int _backtick = 0x60;
const int _doubleQuote = 0x22;
const int _singleQuote = 0x27;
const int _equals = 0x3D;
const int _dollar = 0x24;
const int _underscore = 0x5F;
const int _dot = 0x2E;
const int _hyphen = 0x2D;
const int _colon = 0x3A;

/// One JSX tag, located in the string it was found in.
class JsxTag {
  /// Creates a tag.
  const JsxTag({
    required this.start,
    required this.end,
    required this.name,
    required this.closing,
    required this.selfClosing,
    required this.attributes,
  });

  /// Offset of the `<`.
  final int start;

  /// Offset one past the `>`.
  final int end;

  /// The tag name, dots included.
  final String name;

  /// Whether this is a closing tag.
  final bool closing;

  /// Whether this tag closes itself.
  final bool selfClosing;

  /// Attribute names, in source order, without their values.
  ///
  /// Names only: doc 04 wants "a one-line summary of its attributes" on the
  /// placeholder card, and a name is an identifier — safe to carry through a
  /// fence's info string, where a value containing a backtick or a newline
  /// would not be.
  final List<String> attributes;

  /// Doc 04's locked heuristic: a component tag starts with `[A-Z]` or
  /// contains a dot. A lowercase, dotless tag is HTML and follows the HTML
  /// policy instead — it is left for `RawBlockRewriter`.
  bool get isComponent => isComponentTagName(name);
}

/// Doc 04's locked heuristic, as a predicate: a component tag name starts with
/// `[A-Z]` or contains a dot.
bool isComponentTagName(String name) =>
    name.isNotEmpty && (name.contains('.') || _isUpperCase(name.codeUnitAt(0)));

/// The tag name a `<` at [start] introduces, whether or not that tag ever ends.
///
/// [parseJsxTag] answers "is there a tag here", and returns `null` for one that
/// never closes. The sanitizer needs the other question too — doc 04 bails out
/// on an unbalanced tag, and it cannot bail out on something it could not name.
String? jsxTagNameAt(String source, int start) {
  if (start >= source.length || source.codeUnitAt(start) != _lessThan) {
    return null;
  }
  var i = start + 1;
  if (i < source.length && source.codeUnitAt(i) == _slash) {
    i++;
  }
  if (i >= source.length || !_isNameStart(source.codeUnitAt(i))) {
    return null;
  }
  final nameStart = i;
  i++;
  while (i < source.length && _isNamePart(source.codeUnitAt(i))) {
    i++;
  }
  return source.substring(nameStart, i);
}

/// The result of scanning a block-level region from its opening tag.
class JsxRegion {
  /// Creates a region.
  const JsxRegion({
    required this.open,
    required this.end,
    required this.balanced,
    required this.maxDepth,
  });

  /// The tag the region opened with.
  final JsxTag open;

  /// Offset one past the region's last character.
  ///
  /// Equal to `open.end` when the region never balanced, so a caller that
  /// bails out has a bounded range to emit and does not have to guess where
  /// the author meant the component to stop.
  final int end;

  /// Whether a matching close was found.
  final bool balanced;

  /// The deepest nesting reached, counting the opening tag as depth 1.
  final int maxDepth;
}

/// Parses the tag beginning at [start], or returns `null`.
///
/// `null` means "this `<` does not open a tag" — no terminating `>`, no name,
/// or a name this scanner does not recognise. Every one of those leaves a
/// literal `<` for the caller, which is the safe direction: text left alone
/// can never come out corrupted.
JsxTag? parseJsxTag(String source, int start) {
  if (start >= source.length || source.codeUnitAt(start) != _lessThan) {
    return null;
  }

  var i = start + 1;
  final closing = i < source.length && source.codeUnitAt(i) == _slash;
  if (closing) {
    i++;
  }

  final nameStart = i;
  if (i >= source.length || !_isNameStart(source.codeUnitAt(i))) {
    return null;
  }
  i++;
  while (i < source.length && _isNamePart(source.codeUnitAt(i))) {
    i++;
  }
  final name = source.substring(nameStart, i);

  // A name must be followed by whitespace, a slash, or the end of the tag.
  // Anything else — an autolink like `<https://example.com>`, an email
  // `<a@b.example>` — is not a tag, and has to reach the reader unchanged.
  if (i < source.length) {
    final next = source.codeUnitAt(i);
    if (!_isSpace(next) && next != _greaterThan && next != _slash) {
      return null;
    }
  }

  final attributes = <String>[];
  var selfClosing = false;

  while (i < source.length) {
    final unit = source.codeUnitAt(i);

    if (_isSpace(unit)) {
      // A tag may wrap onto further lines — the fixtures have one that wraps
      // over six — but it may not contain a **blank** line. Without that
      // bound, an unterminated `<Another attr="value"` would scan forward to
      // whatever `>` appears next, however far down the document, and swallow
      // everything in between.
      if (_blankLineAt(source, i)) {
        return null;
      }
      i++;
      continue;
    }
    if (unit == _greaterThan) {
      return JsxTag(
        start: start,
        end: i + 1,
        name: name,
        closing: closing,
        selfClosing: selfClosing,
        attributes: attributes,
      );
    }
    if (unit == _slash) {
      selfClosing = true;
      i++;
      continue;
    }
    if (unit == _openBrace) {
      // A spread (`{...rest}`) or a bare expression attribute, skipped whole
      // so that a `>` inside it cannot end the tag early.
      i = skipBracedExpression(source, i);
      continue;
    }
    if (_isQuote(unit)) {
      i = skipQuoted(source, i);
      continue;
    }
    if (_isNameStart(unit)) {
      final attributeStart = i;
      i++;
      while (i < source.length && _isAttributeNamePart(source.codeUnitAt(i))) {
        i++;
      }
      attributes.add(source.substring(attributeStart, i));
      i = _skipAttributeValue(source, i);
      continue;
    }
    // A character this scanner has no rule for. Doc 04's bail-out is the whole
    // answer to that, and raising it is the caller's job.
    i++;
  }

  return null;
}

/// Scans the block-level region opening at [start].
///
/// Returns `null` when [start] does not open a region at all. Nesting deeper
/// than [depthLimit] does not stop the scan — depth is a counter, so going
/// deeper costs nothing — but it is reported, because doc 04 makes it a
/// bail-out condition rather than a crash.
///
/// [spanLimit] bounds how far the search for a matching close runs. Without it
/// every unclosed tag costs a scan to the end of the file, and a document made
/// of ten thousand unclosed tags is quadratic — which is precisely the shape of
/// input CLAUDE.md rule 9 exists for. Past the limit the region is reported
/// unbalanced, and the caller's bail-out is already the right answer.
JsxRegion? scanJsxRegion(
  String source,
  int start, {
  int depthLimit = 20,
  int spanLimit = 64 * 1024,
}) {
  final open = parseJsxTag(source, start);
  if (open == null || open.closing) {
    return null;
  }
  if (open.selfClosing) {
    return JsxRegion(open: open, end: open.end, balanced: true, maxDepth: 1);
  }

  var depth = 1;
  var maxDepth = 1;
  var i = open.end;
  final stopAt = start + spanLimit < source.length
      ? start + spanLimit
      : source.length;

  while (i < stopAt) {
    final unit = source.codeUnitAt(i);

    if (_isQuote(unit)) {
      i = skipQuoted(source, i);
      continue;
    }
    if (unit == _openBrace) {
      i = skipBracedExpression(source, i);
      continue;
    }
    if (unit != _lessThan) {
      i++;
      continue;
    }

    final tag = parseJsxTag(source, i);
    if (tag == null) {
      i++;
      continue;
    }
    i = tag.end;
    if (tag.selfClosing) {
      continue;
    }
    if (tag.closing) {
      depth--;
      if (depth > 0) {
        continue;
      }
      // The tag that brings the depth back to zero has to be the one that
      // matches: `<A></B></A>` is not a region that ends at `</B>`, it is a
      // document whose author lost track, and doc 04 bails out on exactly
      // that. Intermediate mismatches are tolerated, because a scanner that
      // demanded a well-formed tree would be the JSX parser this is not.
      final matched = depth == 0 && tag.name == open.name;
      return JsxRegion(
        open: open,
        end: matched ? i : open.end,
        balanced: matched,
        maxDepth: maxDepth,
      );
    }
    depth++;
    if (depth > maxDepth) {
      maxDepth = depth;
    }
  }

  return JsxRegion(
    open: open,
    end: open.end,
    balanced: false,
    maxDepth: maxDepth,
  );
}

/// Offset one past the balanced `{…}` beginning at [start], or `null` when the
/// braces never balance.
///
/// Strings inside are skipped whole, so `{"}"}` is one expression rather than
/// two. Callers want the two answers for opposite reasons: the sanitizer must
/// know a brace run is unbalanced, because an unbalanced brace is not an
/// expression and must be left as the literal text it already is, while a tag
/// scanner only wants to get past it.
int? balancedBraceEnd(String source, int start) {
  var depth = 0;
  var i = start;
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (_isQuote(unit)) {
      i = skipQuoted(source, i);
      continue;
    }
    if (unit == _openBrace) {
      depth++;
    } else if (unit == _closeBrace) {
      depth--;
      if (depth == 0) {
        return i + 1;
      }
    }
    i++;
  }
  return null;
}

/// Offset one past the `{…}` beginning at [start], or the end of the string
/// when it never balances.
int skipBracedExpression(String source, int start) =>
    balancedBraceEnd(source, start) ?? source.length;

/// Offset one past the quoted run beginning at [start].
///
/// Backslash escapes are honoured, and an unterminated quote runs to the end
/// of the string rather than failing.
int skipQuoted(String source, int start) {
  final quote = source.codeUnitAt(start);
  var i = start + 1;
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (unit == _backslash) {
      i += 2;
      continue;
    }
    if (unit == quote) {
      return i + 1;
    }
    i++;
  }
  return source.length;
}

/// Wraps [content] in a Markdown code span its own contents cannot break.
///
/// The delimiter is one backtick longer than the longest run inside, and
/// content that starts or ends with a backtick is padded with a space — both
/// are CommonMark's own rules for exactly this, and MDX braces really do carry
/// template literals.
String jsxCodeSpan(String content) {
  if (content.isEmpty) {
    // Padding both sides of nothing gives a span CommonMark strips back to
    // nothing. One space is a space.
    return '` `';
  }
  var longest = 0;
  var run = 0;
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == _backtick) {
      run++;
      if (run > longest) {
        longest = run;
      }
    } else {
      run = 0;
    }
  }
  final fence = '`' * (longest + 1);
  final pad = content.startsWith('`') || content.endsWith('`') ? ' ' : '';
  return '$fence$pad$content$pad$fence';
}

/// Skips whatever follows an attribute name: nothing, or `=` and a value.
int _skipAttributeValue(String source, int from) {
  var i = from;
  while (i < source.length && _isSpace(source.codeUnitAt(i))) {
    i++;
  }
  if (i >= source.length || source.codeUnitAt(i) != _equals) {
    // A valueless attribute (`flag`). The whitespace is left consumed, which
    // is harmless: the tag loop skips it anyway.
    return i;
  }
  i++;
  while (i < source.length && _isSpace(source.codeUnitAt(i))) {
    i++;
  }
  if (i >= source.length) {
    return i;
  }
  final unit = source.codeUnitAt(i);
  if (_isQuote(unit)) {
    return skipQuoted(source, i);
  }
  if (unit == _openBrace) {
    return skipBracedExpression(source, i);
  }
  while (i < source.length &&
      !_isSpace(source.codeUnitAt(i)) &&
      source.codeUnitAt(i) != _greaterThan &&
      source.codeUnitAt(i) != _slash) {
    i++;
  }
  return i;
}

bool _isUpperCase(int unit) => unit >= 0x41 && unit <= 0x5A;

bool _isLowerCase(int unit) => unit >= 0x61 && unit <= 0x7A;

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

bool _isNameStart(int unit) =>
    _isUpperCase(unit) ||
    _isLowerCase(unit) ||
    unit == _underscore ||
    unit == _dollar;

bool _isNamePart(int unit) =>
    _isNameStart(unit) || _isDigit(unit) || unit == _dot || unit == _hyphen;

bool _isAttributeNamePart(int unit) => _isNamePart(unit) || unit == _colon;

bool _isQuote(int unit) =>
    unit == _doubleQuote || unit == _singleQuote || unit == _backtick;

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;

/// Whether the whitespace run at [start] contains a blank line — that is, two
/// line terminators with nothing but spaces and tabs between them.
bool _blankLineAt(String source, int start) {
  var terminators = 0;
  var i = start;
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (unit == 0x0D) {
      terminators++;
      if (i + 1 < source.length && source.codeUnitAt(i + 1) == 0x0A) {
        i++;
      }
    } else if (unit == 0x0A) {
      terminators++;
    } else if (unit != 0x20 && unit != 0x09) {
      return false;
    }
    if (terminators >= 2) {
      return true;
    }
    i++;
  }
  // A run of whitespace to the end of the file ends the document, and a tag
  // that reaches it never closed.
  return true;
}
