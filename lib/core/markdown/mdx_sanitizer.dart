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
/// **Not implemented yet** (M3, doc 15). Two things make the pass-through
/// tolerable in the meantime, and neither makes it correct:
///
/// - MarkLens renders no HTML or JSX at all, so unsanitised MDX shows up as
///   inert text rather than executing (CLAUDE.md rule 2).
/// - Since M1, `RawBlockRewriter` catches block-level `<Component>` tags on
///   the way past. They are HTML blocks by CommonMark start condition 7, so
///   they used to be *deleted* by the renderer with no sign to the reader;
///   now they survive as fenced source. What is still missing is the
///   placeholder card, the ESM chip and the inline chips of doc 04.
///
/// The reader must not claim MDX support until this class is real.
class MdxSanitizer {
  /// Creates a sanitizer.
  const MdxSanitizer();

  /// Transforms MDX [source] into Markdown containing only inert constructs.
  MdxSanitizeResult sanitize(String source) =>
      (source: source, notices: const <DocNotice>[]);
}
