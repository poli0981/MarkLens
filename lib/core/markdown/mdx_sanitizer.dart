import 'package:marklens/core/models/doc_model.dart';

/// The result of transforming MDX into inert Markdown.
typedef MdxSanitizeResult = ({String source, List<DocNotice> notices});

/// Rewrites `.mdx` source so its structure is readable and nothing can run.
///
/// A tolerant scanner, deliberately not a JSX parser: ESM lines are dropped,
/// block-level components become placeholder cards, inline components become
/// chips, and anything it cannot classify is emitted as a fenced `mdx` code
/// block. Bailing out is correct behaviour, not an error — see the placeholder
/// spec in `docs/04_MARKDOWN_PIPELINE.md`.
///
/// **Not implemented yet** (M3, doc 15). The pass-through below is safe in the
/// meantime only because MarkLens renders no HTML or JSX at all: unsanitised
/// MDX shows up as inert text rather than executing (CLAUDE.md rule 2). It is
/// still not correct, and the reader must not claim MDX support until this
/// class is real.
class MdxSanitizer {
  /// Creates a sanitizer.
  const MdxSanitizer();

  /// Transforms MDX [source] into Markdown containing only inert constructs.
  MdxSanitizeResult sanitize(String source) =>
      (source: source, notices: const <DocNotice>[]);
}
