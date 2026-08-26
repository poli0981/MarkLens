/// The one Markdown flavour MarkLens parses, defined in the one place both
/// halves of the pipeline read it from.
///
/// `core/markdown/` parses the source to build the block index and the
/// outline; `features/reader/rendering/` hands the same source to
/// `flutter_markdown_plus`, which parses it again for the widgets. Doc 04
/// accepts that double parse deliberately — but only because the two parses
/// agree. The reader maps `DocModel.blocks[i]` onto the renderer's
/// `children[2i]`, so **a single syntax difference between the two shifts
/// every anchor jump and every search hit, silently**
/// (`docs/spike-results/S1-renderer-bakeoff.md`, Result 4).
///
/// The values below mirror what `flutter_markdown_plus 1.0.12` does inside
/// `MarkdownWidget._parseMarkdown`: `ExtensionSet.gitHubFlavored` (reached via
/// its `?? gitHubFlavored` fallback, since we pass `extensionSet: null`) and
/// `encodeHtml: false`. Changing either one here without changing the renderer
/// is the failure mode this file exists to prevent.
library;

import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

/// The extension set both parses use.
///
/// Note it is `gitHubFlavored`, not `gitHubWeb`: the latter would add
/// `HeaderWithIdSyntax` and populate `Element.generatedId`. We deliberately
/// slug headings ourselves through `HeadingSlugger` instead, because doc 04
/// pins the GitHub algorithm including its Vietnamese combining-mark and
/// duplicate-suffix behaviour, which the package's `generateAnchorHash` does
/// not implement.
final md.ExtensionSet markdownExtensionSet = md.ExtensionSet.gitHubFlavored;

/// Whether the parser HTML-escapes text nodes.
///
/// `false`, matching the renderer. It is what makes inline HTML (`<br>`,
/// `<kbd>`) arrive as literal text rather than as markup — which is exactly
/// the "escaped literal text" doc 04 asks for. Block HTML is a different
/// problem and is handled upstream by `RawBlockRewriter`.
const bool markdownEncodeHtml = false;

/// The block syntaxes a default `md.Document` ends up with, in order.
///
/// Hand-mirrored from two places in `markdown 7.3.1`: `Document`'s constructor
/// adds `extensionSet.blockSyntaxes` first, then `BlockParser`'s constructor
/// appends its `standardBlockSyntaxes`. That second list is an instance member
/// marked `@Deprecated`, so it cannot be referenced — copying it is the only
/// option, and `test/core/parse_mirror_test.dart` is what stops the copy from
/// drifting when the package is bumped.
List<md.BlockSyntax> defaultBlockSyntaxes() => <md.BlockSyntax>[
  ...markdownExtensionSet.blockSyntaxes,
  const md.EmptyBlockSyntax(),
  const md.HtmlBlockSyntax(),
  const md.SetextHeaderSyntax(),
  const md.HeaderSyntax(),
  const md.CodeBlockSyntax(),
  const md.BlockquoteSyntax(),
  const md.HorizontalRuleSyntax(),
  const md.UnorderedListSyntax(),
  const md.OrderedListSyntax(),
  const md.LinkReferenceDefinitionSyntax(),
  const md.ParagraphSyntax(),
];

/// Builds a document configured exactly like the renderer's.
///
/// Passing [blockSyntaxes] replaces the whole block-syntax list — the caller
/// is then responsible for supplying a complete one, normally
/// [defaultBlockSyntaxes] with some entries swapped for subclasses. Default
/// block syntaxes are switched off in that case so the list is not appended
/// to behind the caller's back.
md.Document buildMarkdownDocument({List<md.BlockSyntax>? blockSyntaxes}) {
  if (blockSyntaxes == null) {
    return md.Document(
      extensionSet: markdownExtensionSet,
      encodeHtml: markdownEncodeHtml,
    );
  }
  return md.Document(
    blockSyntaxes: blockSyntaxes,
    inlineSyntaxes: markdownExtensionSet.inlineSyntaxes,
    encodeHtml: markdownEncodeHtml,
    withDefaultBlockSyntaxes: false,
  );
}

/// Splits [source] into lines the way both parsers do.
///
/// `LineSplitter` handles LF, CRLF and lone CR identically to the renderer's
/// own `const LineSplitter().convert(data)`.
List<String> splitMarkdownLines(String source) =>
    const LineSplitter().convert(source);

/// Parses [source] into top-level AST nodes, exactly as the renderer will.
List<md.Node> parseMarkdown(String source) =>
    buildMarkdownDocument().parseLines(splitMarkdownLines(source));
