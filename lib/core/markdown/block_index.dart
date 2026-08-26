import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/recording_syntaxes.dart';
import 'package:marklens/core/markdown/source_lines.dart';
import 'package:marklens/core/models/doc_model.dart';

/// One parse of a document: its top-level nodes, and where each came from.
typedef BlockIndexResult = ({
  /// Blocks in render order, one per entry of [nodes].
  List<SourceBlock> blocks,

  /// The top-level AST nodes, in the order the renderer will build them.
  List<md.Node> nodes,

  /// Whether the parse degraded and the result should not be trusted for
  /// scrolling (CLAUDE.md rule 9).
  bool degraded,
});

/// Locates every top-level block of a document in its source text.
///
/// The `markdown` AST carries no source positions, so this index is built here
/// instead, by parsing with position-recording subclasses of the package's own
/// block syntaxes (`recording_syntaxes.dart`). Search hits
/// (`docs/08_SEARCH.md`) and `#anchor` jumps both resolve through it.
///
/// **The index is over `DocModel.sanitizedSource`** — front matter already
/// lifted out and block HTML already rewritten — because that is the exact
/// string the renderer parses. `blocks[i]` corresponds to the renderer's
/// `children[2i]` (`docs/01_TECH_STACK.md`), and that correspondence is what
/// the whole index exists for.
///
/// Two properties callers may rely on, both locked by tests:
///
/// - **The blocks partition the source.** Every offset in
///   `[0, source.length)` falls inside exactly one block, so a search hit
///   always has somewhere to scroll to. Blank lines and link-reference
///   definitions — which produce no node at all — belong to the block above
///   them.
/// - **Offsets are non-decreasing**, so an offset can be located by binary
///   search rather than a scan.
///
/// There is no guarantee that a document has at least one block. An empty
/// file has none, and so does a file containing only blank lines or only link
/// reference definitions — all three legitimately render as nothing.
class BlockIndexer {
  /// Creates an indexer.
  const BlockIndexer();

  /// Parses [source] and locates its top-level blocks.
  BlockIndexResult index(String source) {
    final lines = SourceLines.of(source);
    final recorder = BlockSpanRecorder();

    final List<md.Node> nodes;
    try {
      nodes = parseRecording(lines.contents, recorder);
    } on Object {
      // Rule 9: no document content may take the app down. `parseLines`
      // throws AssertionError when a syntax combination stops advancing, and
      // nested containers recurse, so StackOverflowError is reachable too.
      // The caller turns this into a plain-text view with a notice.
      return (
        blocks: const <SourceBlock>[],
        nodes: const <md.Node>[],
        degraded: true,
      );
    }

    return _locate(nodes, recorder, lines);
  }

  /// Turns recorded spans into contiguous, non-overlapping blocks.
  static BlockIndexResult _locate(
    List<md.Node> nodes,
    BlockSpanRecorder recorder,
    SourceLines lines,
  ) {
    var degraded = false;

    // Start line per node, in render order. Render order equals source order
    // for everything except the synthesized footnote section, which is last in
    // both orders once it is pinned past the end of the file.
    final starts = <int>[];
    for (final node in nodes) {
      final span = recorder.spanOf(node);
      if (span != null) {
        starts.add(span.startLine);
      } else if (_isSynthesizedFootnoteSection(node)) {
        starts.add(lines.length);
      } else {
        // A top-level node with no recorded position means the syntax list has
        // drifted from the package. Keep the list well-formed so nothing
        // downstream has to handle a hole, and tell the caller not to trust it.
        degraded = true;
        starts.add(starts.isEmpty ? 0 : starts.last);
      }
    }

    final blocks = <SourceBlock>[];
    for (var i = 0; i < nodes.length; i++) {
      // The first block absorbs anything above it — a leading blank line
      // belongs to the document, not to nothing.
      final startLine = i == 0 ? 0 : starts[i];
      final endLineExclusive = i == nodes.length - 1
          ? lines.length
          : starts[i + 1];
      final startOffset = lines.offsetOfLine(startLine);
      final endOffset = lines.offsetOfLine(endLineExclusive);

      blocks.add(
        SourceBlock(
          index: i,
          startLine: startLine,
          // Inclusive, and never before the start: the footnote section is
          // pinned past the last line and so spans nothing at all.
          endLine: endLineExclusive > startLine
              ? endLineExclusive - 1
              : startLine,
          startOffset: startOffset,
          endOffset: endOffset > startOffset ? endOffset : startOffset,
        ),
      );
    }

    return (blocks: blocks, nodes: nodes, degraded: degraded);
  }

  /// Whether [node] is the footnote section `Document` synthesizes at the end
  /// of a document that has footnote definitions.
  ///
  /// It is the one top-level node with no source position of its own: it is
  /// built after parsing, out of definitions lifted from wherever in the file
  /// they were written. It is given an empty range at the end of the source,
  /// so no offset resolves to it and the definitions' own lines stay with the
  /// block they were written under.
  static bool _isSynthesizedFootnoteSection(md.Node node) =>
      node is md.Element &&
      node.tag == 'section' &&
      node.attributes['class'] == 'footnotes';
}
