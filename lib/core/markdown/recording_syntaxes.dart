/// Position-recording block syntaxes: how the pipeline learns where each
/// top-level block came from.
///
/// The `markdown` AST carries no source positions — `Element` exposes
/// `tag / attributes / children / textContent / generatedId / footnoteLabel`
/// and nothing else — while `BlockParser` keeps its cursor in a private field.
/// So the position has to be captured *during* the parse, by the syntaxes
/// themselves.
///
/// **Subclasses, never wrappers.** A decorator that holds a syntax and
/// forwards to it changes the runtime type the parser sees, and the parser
/// branches on that type in at least three places:
///
/// - `SetextHeaderSyntax.canParse` bails unless `parser.currentSyntax is
///   ParagraphSyntax`, so a wrapped paragraph stops setext headings parsing at
///   all;
/// - `BlockParser.parseLines` advances `_start` only for `EmptyBlockSyntax` and
///   `LinkReferenceDefinitionSyntax`, and `_start` backs `linesToConsume`,
///   which is how a setext heading claims the lines above it;
/// - `HtmlBlockSyntax.parse` indents differently when
///   `parser.parentSyntax is ListSyntax`.
///
/// Subclassing keeps every one of those type checks true. The package does the
/// same thing itself — `HeaderWithIdSyntax extends HeaderSyntax`.
library;

import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/markdown_flavor.dart';

/// A source line that remembers which line it is.
///
/// The pipeline builds the line list itself, so it can hand the parser lines
/// that carry their own index. Nested parsers (list items, block quotes,
/// footnote definitions) build fresh lines, so a line that is *not* an
/// [IndexedLine] is a signal that the parse has descended below the top level.
class IndexedLine extends md.Line {
  /// Wraps [content] as line [index] of the document.
  IndexedLine(super.content, this.index);

  /// Zero-based line number in the source the recorder was given.
  final int index;
}

/// The half-open line range a top-level block occupied.
typedef BlockSpan = ({int startLine, int endLineExclusive});

/// Collects a [BlockSpan] for every top-level node produced by one parse.
///
/// Keyed by **node identity**, not by position: `Document` lifts footnote
/// definitions out of their source position and appends a synthesized
/// `section` at the end, so the node list stops being in source order before
/// the caller ever sees it. Identity survives that reshuffle.
class BlockSpanRecorder {
  final Map<md.Node, BlockSpan> _spans = Map<md.Node, BlockSpan>.identity();

  /// The range [node] occupied, or `null` if it was not recorded.
  ///
  /// For a top-level node `null` means either a nested parse produced it or
  /// the syntax list has drifted from the package. Callers treat that as a
  /// reason to degrade, never to guess.
  BlockSpan? spanOf(md.Node node) => _spans[node];

  /// How many spans were recorded.
  int get length => _spans.length;

  void _record(md.Node node, BlockSpan span) => _spans[node] = span;
}

/// Records the span of whatever the syntax it is mixed into parses.
///
/// Recording is skipped unless the parse is at the top level, and that takes
/// two independent checks because neither one covers every nested path:
///
/// - `ListSyntax` and the marker lines of `BlockquoteSyntax` build fresh lines
///   *and* pass a parent syntax, so either check catches them.
/// - A block quote **lazy continuation** line is re-added verbatim — the very
///   same object the top level handed in — so only the parent-syntax check
///   catches it.
/// - `FootnoteDefSyntax` calls `parseLines()` with no parent syntax, so only
///   the line-type check catches it.
///
/// Drop either check and a nested block is counted as a top-level one, which
/// shifts every subsequent scroll target — silently, unless something compares
/// the result against the renderer.
mixin _Recorder on md.BlockSyntax {
  /// Where spans are collected.
  BlockSpanRecorder get recorder;

  /// The line this block starts on, or `null` when the parse is not at the
  /// top level.
  ///
  /// Overridden by the setext subclass, whose block starts earlier than the
  /// line the parser is sitting on.
  int? startLineOf(md.BlockParser parser) {
    if (parser.parentSyntax != null || parser.isDone) {
      return null;
    }
    final line = parser.current;
    return line is IndexedLine ? line.index : null;
  }

  /// Runs the superclass parse and records the range it consumed.
  ///
  /// Generic over the return type because the package narrows it
  /// inconsistently — `TableSyntax`, `FootnoteDefSyntax`,
  /// `SetextHeaderSyntax` and `ParagraphSyntax` return `Node?` while the rest
  /// return a non-nullable `Node`. A mixin declaring either signature could
  /// not legally override the other, so each subclass keeps its own and routes
  /// through here.
  T recordedParse<T extends md.Node?>(
    md.BlockParser parser,
    T Function() runSuper,
  ) {
    final start = startLineOf(parser);
    final node = runSuper();
    if (node == null || start == null) {
      return node;
    }
    final current = parser.isDone ? null : parser.current;
    final end = current is IndexedLine ? current.index : parser.lines.length;
    recorder._record(node, (startLine: start, endLineExclusive: end));
    return node;
  }
}

class _RecordingFencedCodeBlockSyntax extends md.FencedCodeBlockSyntax
    with _Recorder {
  _RecordingFencedCodeBlockSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingTableSyntax extends md.TableSyntax with _Recorder {
  _RecordingTableSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node? parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingUnorderedListWithCheckboxSyntax
    extends md.UnorderedListWithCheckboxSyntax
    with _Recorder {
  _RecordingUnorderedListWithCheckboxSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingOrderedListWithCheckboxSyntax
    extends md.OrderedListWithCheckboxSyntax
    with _Recorder {
  _RecordingOrderedListWithCheckboxSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingFootnoteDefSyntax extends md.FootnoteDefSyntax with _Recorder {
  _RecordingFootnoteDefSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node? parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingHtmlBlockSyntax extends md.HtmlBlockSyntax with _Recorder {
  _RecordingHtmlBlockSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

/// Setext headings are the one syntax whose block starts *before* the line the
/// parser is on when `parse` runs.
///
/// `SetextHeaderSyntax.canParse` only fires on the underline, and `parse` then
/// reaches back through `parser.linesToConsume` for the heading text above it.
/// Recording the current line would put the heading a line or more too late,
/// and every anchor jump to it would land short. This is the only consumer of
/// `linesToConsume` in the package, so it is exactly one special case.
class _RecordingSetextHeaderSyntax extends md.SetextHeaderSyntax
    with _Recorder {
  _RecordingSetextHeaderSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  int? startLineOf(md.BlockParser parser) {
    if (parser.parentSyntax != null || parser.isDone) {
      return null;
    }
    final consumed = parser.linesToConsume;
    if (consumed.isEmpty) {
      return super.startLineOf(parser);
    }
    final first = consumed.first;
    return first is IndexedLine ? first.index : super.startLineOf(parser);
  }

  @override
  md.Node? parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingHeaderSyntax extends md.HeaderSyntax with _Recorder {
  _RecordingHeaderSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingCodeBlockSyntax extends md.CodeBlockSyntax with _Recorder {
  _RecordingCodeBlockSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingBlockquoteSyntax extends md.BlockquoteSyntax with _Recorder {
  _RecordingBlockquoteSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingHorizontalRuleSyntax extends md.HorizontalRuleSyntax
    with _Recorder {
  _RecordingHorizontalRuleSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingUnorderedListSyntax extends md.UnorderedListSyntax
    with _Recorder {
  _RecordingUnorderedListSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingOrderedListSyntax extends md.OrderedListSyntax with _Recorder {
  _RecordingOrderedListSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

class _RecordingParagraphSyntax extends md.ParagraphSyntax with _Recorder {
  _RecordingParagraphSyntax(this.recorder);

  @override
  final BlockSpanRecorder recorder;

  @override
  md.Node? parse(md.BlockParser parser) =>
      recordedParse(parser, () => super.parse(parser));
}

/// The renderer's block-syntax list, in order, with every entry that can
/// produce a node replaced by a recording subclass.
///
/// `EmptyBlockSyntax` and `LinkReferenceDefinitionSyntax` are the package's own
/// instances: both always return `null`, so there is nothing to record, and
/// leaving them untouched keeps the `_start` bookkeeping in `BlockParser` —
/// which tests them by type — provably unchanged.
///
/// The order mirrors `defaultBlockSyntaxes()`;
/// `test/core/parse_mirror_test.dart` is what holds the two together.
List<md.BlockSyntax> recordingBlockSyntaxes(BlockSpanRecorder recorder) =>
    <md.BlockSyntax>[
      _RecordingFencedCodeBlockSyntax(recorder),
      _RecordingTableSyntax(recorder),
      _RecordingUnorderedListWithCheckboxSyntax(recorder),
      _RecordingOrderedListWithCheckboxSyntax(recorder),
      _RecordingFootnoteDefSyntax(recorder),
      const md.EmptyBlockSyntax(),
      _RecordingHtmlBlockSyntax(recorder),
      _RecordingSetextHeaderSyntax(recorder),
      _RecordingHeaderSyntax(recorder),
      _RecordingCodeBlockSyntax(recorder),
      _RecordingBlockquoteSyntax(recorder),
      _RecordingHorizontalRuleSyntax(recorder),
      _RecordingUnorderedListSyntax(recorder),
      _RecordingOrderedListSyntax(recorder),
      const md.LinkReferenceDefinitionSyntax(),
      _RecordingParagraphSyntax(recorder),
    ];

/// Parses [lines] while recording where each top-level block came from.
List<md.Node> parseRecording(List<String> lines, BlockSpanRecorder recorder) =>
    buildMarkdownDocument(
      blockSyntaxes: recordingBlockSyntaxes(recorder),
    ).parseLineList(<md.Line>[
      for (var i = 0; i < lines.length; i++) IndexedLine(lines[i], i),
    ]);
