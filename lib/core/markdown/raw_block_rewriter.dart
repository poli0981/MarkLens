import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/recording_syntaxes.dart';
import 'package:marklens/core/markdown/source_lines.dart';

/// The marker that tells the reader a `pre` block was rescued rather than
/// written.
///
/// It arrives as `pre.attributes['data-metadata']`, because the parser splits
/// a fence's info string into a language and everything after it. The reader
/// draws a "Raw HTML (not rendered)" box when it sees this and an ordinary
/// code block when it does not (`docs/04_MARKDOWN_PIPELINE.md`, ARB key
/// `readerRawHtmlTitle`).
const String rawBlockMetadata = 'marklens-raw';

/// The language the rescued block is highlighted as.
const String rawBlockLanguage = 'html';

/// The whole info string the rewriter puts on the fences it emits.
///
/// The first word keeps the body highlighting as HTML; the rest is the marker.
/// Built from the two constants above so the writer and the reader cannot
/// drift apart.
const String rawBlockFenceInfo = '$rawBlockLanguage $rawBlockMetadata';

/// The result of rewriting a document's block HTML.
typedef RawBlockRewrite = ({String source, int rewritten});

/// Rewrites block-level HTML into fenced code blocks before the renderer sees
/// the document.
///
/// Doc 04 says MarkLens renders no HTML and shows block HTML as a collapsed
/// "Raw HTML (not rendered)" box. That box cannot be built by styling the
/// renderer's output, because `flutter_markdown_plus` emits **nothing at all**
/// for block HTML: `HtmlBlockSyntax` returns a bare `md.Text` node, and the
/// builder's `visitText` opens with `if (_blocks.last.tag == null) return;`.
/// The content is deleted, and the reader gets no sign anything was there
/// (`docs/spike-results/S1-renderer-bakeoff.md`, Result 3).
///
/// That deletion is also an arithmetic problem, which is why this ships in M1
/// rather than later: a top-level `md.Text` is **one AST node and zero renderer
/// children**, so `blocks[i] -> children[2i]` is already wrong for any document
/// containing block HTML. Rewriting each region into a fenced code block
/// restores the one-to-one mapping as a side effect of making the content
/// visible again.
///
/// **The regions are found by the parser, not by a scanner of our own.** The
/// set of top-level `md.Text` nodes *is* the set of block-HTML regions, by the
/// package's own CommonMark implementation. That brings the seven start
/// conditions, the rule that a blank line closes a type-6 block (so
/// `<details>` … blank line … `</details>` is correctly two regions), an
/// unterminated block running to end of file, and the fact that a tag which is
/// not at the start of its line is inline HTML and must be left alone — none of
/// which we would want to re-derive.
///
/// **MDX.** A block-level `<Component>` on a line of its own is an HTML block
/// by CommonMark start condition 7 — the tag-name pattern is
/// `[a-zA-Z][a-zA-Z0-9-]*`, which capitalized names match — so the renderer
/// deletes it exactly like a `<div>`, and it is rescued here by exactly the
/// same code path, with no MDX-specific rule. A *dotted* tag such as
/// `<Foo.Bar />` is not an HTML block at all, because `.` is not legal in an
/// HTML tag name; it stays a paragraph and already renders as literal text, so
/// it is left alone until `MdxSanitizer` lands in M3.
///
/// Known gap, recorded in doc 04: HTML nested inside a list item or block quote
/// still disappears. It does not break the block arithmetic — the enclosing
/// top-level block still produces exactly one child — and reaching it needs
/// nested line ranges the recorder deliberately does not collect.
class RawBlockRewriter {
  /// Creates a rewriter.
  const RawBlockRewriter();

  static const int _backtick = 0x60;
  static const int _lineFeed = 0x0A;

  /// Rewrites every top-level block-HTML region of [source].
  ///
  /// Returns the source unchanged, and a count of zero, when there is nothing
  /// to rewrite or when the parse fails — leaving a document alone is always
  /// safe, and the parse failure is reported by `BlockIndexer` downstream
  /// (CLAUDE.md rule 9).
  RawBlockRewrite rewrite(String source) {
    final lines = SourceLines.of(source);
    final recorder = BlockSpanRecorder();

    final List<md.Node> nodes;
    try {
      nodes = parseRecording(lines.contents, recorder);
    } on Object {
      return (source: source, rewritten: 0);
    }

    final regions = <BlockSpan>[];
    for (final node in nodes) {
      if (node is! md.Text) {
        continue;
      }
      final span = recorder.spanOf(node);
      if (span != null && span.endLineExclusive > span.startLine) {
        regions.add(span);
      }
    }
    if (regions.isEmpty) {
      return (source: source, rewritten: 0);
    }

    // Splice by offset rather than rejoining lines: everything outside a
    // rewritten region must come through byte for byte, line terminators
    // included. Regions arrive in source order and never overlap, so a single
    // forward pass with a cursor is enough.
    final fallbackEol = _documentTerminator(source);
    final buffer = StringBuffer();
    var cursor = 0;

    for (final region in regions) {
      final start = lines.offsetOfLine(region.startLine);
      final end = lines.offsetOfLine(region.endLineExclusive);
      final body = source.substring(start, end);
      final bodyEol = _trailingTerminator(body);
      final eol = bodyEol ?? fallbackEol;
      final marker = _fenceMarker(body);

      buffer
        ..write(source.substring(cursor, start))
        ..write(marker)
        ..write(rawBlockFenceInfo)
        ..write(eol)
        ..write(body);
      if (bodyEol == null) {
        buffer.write(eol);
      }
      buffer.write(marker);
      if (bodyEol != null) {
        buffer.write(bodyEol);
      }
      cursor = end;
    }
    buffer.write(source.substring(cursor));

    return (source: buffer.toString(), rewritten: regions.length);
  }

  /// The backtick run to fence [body] with.
  ///
  /// CommonMark closes a fence only with a run at least as long as the opening
  /// one, so one more backtick than the longest run inside makes the content
  /// uncloseable — which matters, because raw HTML is exactly the kind of thing
  /// that ends up quoting a code sample.
  static String _fenceMarker(String body) {
    var longestRun = 0;
    var run = 0;
    for (var i = 0; i < body.length; i++) {
      if (body.codeUnitAt(i) == _backtick) {
        run++;
        if (run > longestRun) {
          longestRun = run;
        }
      } else {
        run = 0;
      }
    }
    return '`' * (longestRun >= 3 ? longestRun + 1 : 3);
  }

  /// The line terminator [text] ends with, or `null` if it ends mid-line.
  static String? _trailingTerminator(String text) {
    if (text.endsWith('\r\n')) {
      return '\r\n';
    }
    if (text.endsWith('\n') || text.endsWith('\r')) {
      return text.substring(text.length - 1);
    }
    return null;
  }

  /// The terminator to use for the lines this rewriter adds.
  ///
  /// Only reached when a region runs to the end of a file that has no final
  /// newline — which is exactly the unterminated `<div>` at the end of
  /// `test/fixtures/torture/gfm/06_footnotes_and_html.md`.
  static String _documentTerminator(String source) {
    final carriageReturn = source.indexOf('\r');
    if (carriageReturn == -1) {
      return '\n';
    }
    return carriageReturn + 1 < source.length &&
            source.codeUnitAt(carriageReturn + 1) == _lineFeed
        ? '\r\n'
        : '\r';
  }
}
