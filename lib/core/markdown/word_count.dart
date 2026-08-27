/// Counting the words a reader would see, for the status bar (`docs/06_UI_UX.md`).
///
/// Pure Dart, like everything else under `core/` (CLAUDE.md rule 3).
library;

/// Counts the words in [source].
///
/// **Not a whitespace split.** Japanese is written without spaces, so splitting
/// on whitespace reports a 4,000-character Japanese document as roughly one
/// word — and `docs/09_I18N.md` makes Japanese a first-class locale rather than
/// an afterthought. Each CJK ideograph or kana therefore counts as one word,
/// which is the convention every Japanese word processor uses, while spaced
/// scripts keep counting runs between separators. Vietnamese needs nothing
/// special: its combining marks are ordinary non-separator characters and stay
/// inside the run they belong to.
///
/// Fenced code is skipped. A reader asking "how long is this document" means
/// the prose, and a code sample would otherwise dominate the number; it is also
/// how the rescued raw-HTML blocks stay out of the count, since
/// `RawBlockRewriter` turns those into fences too (`docs/04_MARKDOWN_PIPELINE.md`).
///
/// A run has to contain at least one letter or digit to count, so a table rule
/// (`|---|---|`), a thematic break or a lone bullet is punctuation rather than
/// a word.
int countWords(String source) {
  if (source.isEmpty) {
    return 0;
  }

  var words = 0;
  var runHasLetter = false;
  String? fenceChar;
  var fenceLength = 0;
  var lineStart = 0;
  var skippingLine = false;

  void endRun() {
    if (runHasLetter) {
      words++;
      runHasLetter = false;
    }
  }

  void startLine(int start, int end) {
    final fence = _fenceAt(source, start, end);
    if (fence == null) {
      skippingLine = fenceChar != null;
      return;
    }
    if (fenceChar == null) {
      fenceChar = fence.char;
      fenceLength = fence.length;
      skippingLine = true;
    } else if (fence.char == fenceChar && fence.length >= fenceLength) {
      fenceChar = null;
      fenceLength = 0;
      skippingLine = true;
    } else {
      skippingLine = true;
    }
  }

  for (var i = 0; i <= source.length; i++) {
    final atEnd = i == source.length;
    final code = atEnd ? 0x0A : source.codeUnitAt(i);

    if (i == lineStart && !atEnd) {
      startLine(lineStart, _lineEnd(source, lineStart));
    }

    if (code == 0x0A) {
      endRun();
      lineStart = i + 1;
      if (atEnd) {
        break;
      }
      continue;
    }
    if (skippingLine) {
      continue;
    }

    if (_isSeparator(code)) {
      endRun();
    } else if (_isCjk(code)) {
      // One character, one word — and it also terminates whatever Latin run
      // was in progress, since CJK text is routinely mixed with ASCII.
      endRun();
      words++;
    } else {
      runHasLetter = runHasLetter || _isLetterOrDigit(code);
    }
  }

  return words;
}

int _lineEnd(String source, int start) {
  final index = source.indexOf('\n', start);
  return index == -1 ? source.length : index;
}

/// The fence a line opens or closes, or `null` if it is not a fence line.
///
/// CommonMark allows up to three spaces of indentation and a run of at least
/// three backticks or tildes.
({String char, int length})? _fenceAt(String source, int start, int end) {
  var i = start;
  var indent = 0;
  while (i < end && source.codeUnitAt(i) == 0x20 && indent < 4) {
    i++;
    indent++;
  }
  if (indent > 3 || i >= end) {
    return null;
  }
  final code = source.codeUnitAt(i);
  if (code != 0x60 && code != 0x7E) {
    return null;
  }
  var length = 0;
  while (i < end && source.codeUnitAt(i) == code) {
    i++;
    length++;
  }
  if (length < 3) {
    return null;
  }
  return (char: String.fromCharCode(code), length: length);
}

/// Whitespace, CJK punctuation, and the general-punctuation block.
///
/// CJK punctuation (`、`, `。`, `「`) is listed because it separates words in
/// exactly the way a space does, and counting it as a character would inflate
/// every Japanese count by its punctuation.
bool _isSeparator(int code) =>
    code == 0x20 ||
    code == 0x09 ||
    code == 0x0D ||
    code == 0x0C ||
    code == 0x0B ||
    (code >= 0x2000 && code <= 0x206F) ||
    (code >= 0x3000 && code <= 0x303F);

/// Ideographs and kana, each of which counts as one word.
///
/// Hangul is deliberately absent: Korean is written with spaces, so it counts
/// the same way Latin does.
bool _isCjk(int code) =>
    (code >= 0x3040 && code <= 0x30FF) ||
    (code >= 0x31F0 && code <= 0x31FF) ||
    (code >= 0x3400 && code <= 0x4DBF) ||
    (code >= 0x4E00 && code <= 0x9FFF) ||
    (code >= 0xF900 && code <= 0xFAFF) ||
    (code >= 0xFF66 && code <= 0xFF9F);

/// Whether [code] is substantial enough to make its run a word.
///
/// Anything outside ASCII that is neither a separator nor CJK is treated as a
/// letter, which is what carries Vietnamese, Greek, Cyrillic and the rest
/// without a Unicode table.
bool _isLetterOrDigit(int code) =>
    (code >= 0x61 && code <= 0x7A) ||
    (code >= 0x41 && code <= 0x5A) ||
    (code >= 0x30 && code <= 0x39) ||
    code > 0x7F;
