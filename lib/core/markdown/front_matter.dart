import 'package:marklens/core/markdown/source_lines.dart';
import 'package:marklens/core/models/doc_model.dart';

/// The result of lifting a leading `---` block off a document.
typedef FrontMatterSplit = ({String body, FrontMatter? frontMatter});

/// Separates a document's leading `---` front-matter block from its body.
///
/// Front-matter is never fed to the renderer; it is shown as a collapsible
/// key/value panel instead (`docs/04_MARKDOWN_PIPELINE.md`). YAML that is not
/// simple `key: value` lines is kept and shown raw — never fatal.
///
/// Hand-written rather than delegating to a YAML package, for two reasons that
/// point the same way: `core/` may only import the packages
/// `test/architecture/core_purity_test.dart` allows, and doc 04 asks for
/// exactly one shape — flat `key: value` — with everything else shown raw.
/// Doc 13 prefers fifty lines of our own code over a utility dependency.
///
/// Three rules doc 04 left open, decided here and recorded in it:
///
/// - **No closing fence means no front matter.** A file that opens with `---`
///   and never closes is treated as an ordinary document, because the
///   alternative is swallowing the entire document into a panel (rule 9).
/// - **A line that is not `key: value` makes the whole block unparsed** —
///   including YAML comments and nested keys. `parsed` false is not an error;
///   it selects the raw view of the panel.
/// - **A repeated key keeps the last value**, and insertion order is the order
///   the panel shows.
class FrontMatterSplitter {
  /// Creates a splitter.
  const FrontMatterSplitter();

  /// A key that is flat, unquoted and starts at column zero. Anything else —
  /// indentation, a bare list item, a comment — makes the block unparsed.
  static final RegExp _field = RegExp(r'^([A-Za-z0-9_.-]+):(.*)$');

  /// Splits [source] into its front-matter block and its body.
  FrontMatterSplit split(String source) {
    final lines = SourceLines.of(source);
    if (lines.length < 2 || !_opensFence(lines.contents.first)) {
      return (body: source, frontMatter: null);
    }

    final close = _closingFenceLine(lines);
    if (close == null) {
      return (body: source, frontMatter: null);
    }

    final raw = _stripTerminator(
      source.substring(lines.offsetOfLine(1), lines.offsetOfLine(close)),
    );
    final fields = _parseFields(lines.contents.getRange(1, close));

    return (
      body: source.substring(lines.offsetOfLine(close + 1)),
      frontMatter: FrontMatter(
        raw: raw,
        fields: fields ?? const <String, String>{},
        parsed: fields != null,
      ),
    );
  }

  /// Whether [line] opens the block: `---` on the very first line, with no
  /// indentation. Trailing whitespace is tolerated because editors add it.
  static bool _opensFence(String line) => line.trimRight() == '---';

  /// Index of the first line that closes the block, or `null` if none does.
  ///
  /// Both YAML terminators are accepted; `...` is rare in front matter but
  /// costs one comparison to support.
  static int? _closingFenceLine(SourceLines lines) {
    for (var i = 1; i < lines.length; i++) {
      final content = lines.contents[i].trimRight();
      if (content == '---' || content == '...') {
        return i;
      }
    }
    return null;
  }

  /// Parses [lines] as flat `key: value` pairs, or returns `null` if any
  /// non-blank line is not one.
  static Map<String, String>? _parseFields(Iterable<String> lines) {
    final fields = <String, String>{};
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      final match = _field.firstMatch(line);
      if (match == null) {
        return null;
      }
      fields[match[1]!] = match[2]!.trim();
    }
    return fields;
  }

  /// Drops the single line terminator before the closing fence, so [raw] is
  /// the block as written without a trailing blank.
  static String _stripTerminator(String raw) {
    if (raw.endsWith('\r\n')) {
      return raw.substring(0, raw.length - 2);
    }
    if (raw.endsWith('\n') || raw.endsWith('\r')) {
      return raw.substring(0, raw.length - 1);
    }
    return raw;
  }
}
