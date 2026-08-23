import 'package:marklens/core/models/doc_model.dart';

/// Locates every top-level block of a document in its source text.
///
/// The `markdown` package's AST carries no source positions, so this index is
/// built here instead. Search hits (`docs/08_SEARCH.md`) and `#anchor` jumps
/// both resolve through it, which is why it belongs to the pure-Dart half of
/// the pipeline rather than to whichever renderer S1 picks.
///
/// **Not implemented yet** (M2, doc 15). The single whole-document block below
/// is a defined placeholder rather than an empty list, so callers can assume
/// there is always at least one block to aim at.
class BlockIndexer {
  /// Creates an indexer.
  const BlockIndexer();

  /// Returns the blocks of [source], in document order.
  List<SourceBlock> index(String source) => <SourceBlock>[
    SourceBlock(
      index: 0,
      startLine: 0,
      endLine: '\n'.allMatches(source).length,
      startOffset: 0,
      endOffset: source.length,
    ),
  ];
}
