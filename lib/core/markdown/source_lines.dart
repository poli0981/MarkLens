/// Line boundaries of a source string, computed once and shared.
///
/// Three stages need the same answer to "where does line N start?":
/// `FrontMatterSplitter` has to cut the body at a fence, `RawBlockRewriter` has
/// to replace a line range, and `BlockIndexer` has to turn the line indices it
/// records during parsing into the character offsets `SourceBlock` carries.
/// Computing it three different ways is how the three quietly disagree.
///
/// The split must match `LineSplitter` exactly, because that is what both
/// `markdown` and `flutter_markdown_plus` use to cut the source into lines —
/// `test/core/source_lines_test.dart` asserts the agreement rather than
/// assuming it.
library;

/// The lines of a source string, with their offsets.
class SourceLines {
  SourceLines._(this.source, this.contents, this.starts);

  /// Scans [source] into lines, splitting on LF, CR and CRLF alike.
  factory SourceLines.of(String source) {
    final contents = <String>[];
    final starts = <int>[];
    var lineStart = 0;
    var i = 0;
    while (i < source.length) {
      final unit = source.codeUnitAt(i);
      if (unit == _lf || unit == _cr) {
        contents.add(source.substring(lineStart, i));
        starts.add(lineStart);
        // A CRLF pair is one terminator, not two.
        if (unit == _cr &&
            i + 1 < source.length &&
            source.codeUnitAt(i + 1) == _lf) {
          i++;
        }
        i++;
        lineStart = i;
      } else {
        i++;
      }
    }
    // A trailing terminator does not open a final empty line, matching
    // LineSplitter.
    if (lineStart < source.length) {
      contents.add(source.substring(lineStart));
      starts.add(lineStart);
    }
    return SourceLines._(source, contents, starts);
  }

  static const int _lf = 0x0A;
  static const int _cr = 0x0D;

  /// The string these lines came from.
  final String source;

  /// Each line's text, terminator excluded.
  final List<String> contents;

  /// Each line's first character offset into [source].
  final List<int> starts;

  /// How many lines the source has.
  int get length => contents.length;

  /// Offset where line [index] begins.
  ///
  /// An [index] at or past the end returns `source.length`, so a block that
  /// runs to the end of the file needs no special case at the call site.
  int offsetOfLine(int index) =>
      index < starts.length ? starts[index] : source.length;
}
