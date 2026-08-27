/// Literal search inside one document (`docs/08_SEARCH.md`, "Find in file").
///
/// Pure Dart, and deliberately literal: doc 08 keeps regex as a v1.x
/// candidate, and a query someone types into a find bar should not quietly be
/// a pattern.
library;

import 'package:marklens/core/models/doc_model.dart';

/// One match: where it starts, how long it is, and which block renders it.
typedef FindHit = ({int offset, int length, int blockIndex});

/// Every non-overlapping match of [query] in [source].
///
/// **[source] must be `DocModel.sanitizedSource`.** That is the exact string
/// `SourceBlock` indexes, so a hit offset resolves to a block with no
/// translation step — doc 08 chose this over maintaining a raw-to-sanitized
/// offset map, which would have to be rebuilt every time the MDX sanitizer
/// changed a length, for the payoff of one shared match counter.
///
/// Front matter is therefore not searched here: it is lifted out before
/// `sanitizedSource` exists, and doc 08 gives the panel its own surface over
/// `FrontMatter.raw`.
List<FindHit> findInSource({
  required String source,
  required List<SourceBlock> blocks,
  required String query,
  bool caseSensitive = false,
}) {
  if (query.isEmpty || source.isEmpty) {
    return const <FindHit>[];
  }

  var haystack = source;
  var needle = query;
  if (!caseSensitive) {
    final folded = source.toLowerCase();
    // Every offset this function returns indexes the *unfolded* source, so the
    // fold has to be length-preserving or a single shifted character
    // desynchronises every hit after it.
    //
    // Dart's `toLowerCase` uses simple case mapping and does preserve length
    // today — measured on the usual suspects, including `İ`, `ẞ` and the
    // titlecase digraphs, all of which full Unicode mapping would lengthen.
    // The check stays because this arithmetic *depends* on that and nothing
    // else enforces it; if it ever stops being true, the search degrades to
    // case-sensitive rather than pointing at the wrong characters (rule 9).
    if (folded.length == source.length) {
      haystack = folded;
      needle = query.toLowerCase();
    }
  }

  final hits = <FindHit>[];
  var from = 0;
  while (true) {
    final at = haystack.indexOf(needle, from);
    if (at < 0) {
      break;
    }
    hits.add((
      offset: at,
      length: needle.length,
      blockIndex: blockIndexOf(blocks, at),
    ));
    // Non-overlapping: "aa" in "aaaa" is two matches, not three.
    from = at + needle.length;
  }
  return hits;
}

/// The block containing [offset], or `-1` if no block does.
///
/// Binary search: doc 04 guarantees the blocks partition the source and that
/// their offsets are non-decreasing, which is exactly what makes this possible.
///
/// The membership check is not decoration. A document with footnotes ends with
/// a synthesized section that has an **empty range** at the end of the source
/// (doc 04), so "the last block whose start is at or before the offset" can
/// land on a block that contains nothing at all.
int blockIndexOf(List<SourceBlock> blocks, int offset) {
  if (blocks.isEmpty) {
    return -1;
  }
  var low = 0;
  var high = blocks.length - 1;
  var candidate = -1;
  while (low <= high) {
    final middle = (low + high) ~/ 2;
    if (blocks[middle].startOffset <= offset) {
      candidate = middle;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  if (candidate < 0) {
    return -1;
  }
  // Step back over any empty block that starts here but holds nothing.
  var index = candidate;
  while (index >= 0 && !blocks[index].contains(offset)) {
    index--;
  }
  return index;
}
