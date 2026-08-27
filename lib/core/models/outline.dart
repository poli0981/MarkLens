/// The heading tree extracted from a document, used by the outline panel,
/// `#anchor` links and cross-file `file.md#anchor` links.
///
/// Pure data. Nothing here may reference Flutter (CLAUDE.md rule 3).
class Outline {
  /// Creates an outline from a flat, document-order list of [entries].
  const Outline(this.entries);

  /// An outline with no headings — the correct result for a heading-less
  /// document, not an error (docs/06_UI_UX.md).
  static const Outline empty = Outline(<OutlineEntry>[]);

  /// Headings in document order. Nesting is expressed by
  /// [OutlineEntry.level], not by a child list, because scroll-spy and the
  /// find bar both want a flat ordered list.
  final List<OutlineEntry> entries;

  /// Whether the document has no headings at all.
  bool get isEmpty => entries.isEmpty;

  /// The heading a reader looking at [blockIndex] is underneath.
  ///
  /// This is scroll-spy: entries are in document order, so the answer is the
  /// last one that starts at or before the block on screen. `null` above the
  /// first heading — a document may well open with a paragraph.
  ///
  /// Headings nested in a list or a block quote share the enclosing block's
  /// index (doc 04), so several entries can answer for one block; the last of
  /// them wins, which is the innermost heading the reader has passed.
  OutlineEntry? headingAt(int blockIndex) {
    OutlineEntry? found;
    for (final entry in entries) {
      if (entry.blockIndex > blockIndex) {
        break;
      }
      found = entry;
    }
    return found;
  }

  /// The entry with [slug], or `null` — for `#anchor` links (doc 03).
  OutlineEntry? bySlug(String slug) {
    for (final entry in entries) {
      if (entry.slug == slug) {
        return entry;
      }
    }
    return null;
  }
}

/// A single heading in the [Outline].
class OutlineEntry {
  /// Creates a heading entry.
  const OutlineEntry({
    required this.level,
    required this.text,
    required this.slug,
    required this.blockIndex,
  });

  /// Heading level, 1–6 (`#` through `######`).
  final int level;

  /// The heading's rendered text, with Markdown formatting already removed.
  final String text;

  /// GitHub-compatible anchor slug, unique within the document.
  ///
  /// Produced by `HeadingSlugger` in `core/markdown/slug.dart`.
  final String slug;

  /// Index into `DocModel.blocks` of the block this heading starts.
  ///
  /// This is what makes "jump to heading" and "scroll to search hit" the same
  /// operation — see `docs/04_MARKDOWN_PIPELINE.md`.
  final int blockIndex;
}
