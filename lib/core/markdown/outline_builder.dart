import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/slug.dart';
import 'package:marklens/core/models/outline.dart';

/// Builds the heading outline from a parsed document.
///
/// The outline drives the outline panel and scroll-spy (`docs/06_UI_UX.md`),
/// `#anchor` links, and the "keep position by nearest heading" behaviour when a
/// watched file is re-parsed (`docs/03_DATA_FLOW.md`). Entries are flat and
/// carry their [OutlineEntry.level]; nesting is not expressed as a tree,
/// because scroll-spy and the find bar both want an ordered list.
///
/// **Nested headings are included.** A heading inside a block quote or a list
/// item is not a top-level block, so it has no block of its own to scroll to —
/// it carries the index of the top-level block that contains it. Skipping such
/// headings instead would be worse than imprecise: `HeadingSlugger` numbers
/// duplicates in document order, so leaving one out would shift the `-1`/`-2`
/// suffix of every later heading with the same text and silently break the
/// anchors of headings that are not nested at all.
///
/// The walk is iterative. `test/fixtures/torture/edge/deep_nesting.md` has
/// thirteen list levels and twelve block-quote levels, and
/// `generateDeepMdxNesting()` exists specifically to break a recursive walker.
class OutlineBuilder {
  /// Creates a builder.
  const OutlineBuilder();

  /// Builds the outline for [nodes], the top-level nodes of one parse.
  ///
  /// [nodes] must be in render order, so that the index of each entry's
  /// enclosing node is the index of the block that renders it.
  Outline build(List<md.Node> nodes) {
    final slugger = HeadingSlugger();
    final entries = <OutlineEntry>[];

    for (var blockIndex = 0; blockIndex < nodes.length; blockIndex++) {
      final stack = <md.Node>[nodes[blockIndex]];
      while (stack.isNotEmpty) {
        final node = stack.removeLast();
        if (node is! md.Element) {
          continue;
        }

        final level = _headingLevel(node.tag);
        if (level != null) {
          final text = node.textContent.trim();
          entries.add(
            OutlineEntry(
              level: level,
              text: text,
              slug: slugger.slug(text),
              blockIndex: blockIndex,
            ),
          );
        }

        final children = node.children;
        if (children != null) {
          // Reversed, so popping the stack yields document order.
          for (var i = children.length - 1; i >= 0; i--) {
            stack.add(children[i]);
          }
        }
      }
    }

    return entries.isEmpty ? Outline.empty : Outline(entries);
  }

  /// The heading level of [tag], or `null` if it is not a heading.
  static int? _headingLevel(String tag) {
    if (tag.length != 2 || tag.codeUnitAt(0) != _lowercaseH) {
      return null;
    }
    final digit = tag.codeUnitAt(1) - _zero;
    return digit >= 1 && digit <= 6 ? digit : null;
  }

  static const int _lowercaseH = 0x68;
  static const int _zero = 0x30;
}
