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
