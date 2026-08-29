import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';

/// Turns the doc 06 tokens into the renderer's style sheet.
///
/// The renderer never picks a colour of its own: everything it draws comes
/// from here, which is what stops a Material default appearing next to a token
/// colour and looking almost right. It is also what makes the S1 decision
/// reversible — a different renderer package needs a new style sheet, not a
/// new palette (`docs/02_ARCHITECTURE.md`, "The seam").
abstract final class ReaderStyle {
  /// Body text size at 100% zoom, before the reading scale is applied.
  static const double baseFontSize = 16;

  /// Builds the style sheet for [context].
  static MarkdownStyleSheet of(BuildContext context) {
    final tokens = ReaderTokens.of(context);

    TextStyle body(double size, {FontWeight? weight, double height = 1.6}) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: tokens.fg,
        );

    final code = TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: monoFallback,
      fontSize: baseFontSize * 0.85,
      height: 1.45,
      color: tokens.fg,
      backgroundColor: tokens.codeBg,
    );

    return MarkdownStyleSheet(
      p: body(baseFontSize),
      h1: body(baseFontSize * 2, weight: FontWeight.w700, height: 1.25),
      h2: body(baseFontSize * 1.5, weight: FontWeight.w700, height: 1.3),
      h3: body(baseFontSize * 1.25, weight: FontWeight.w600, height: 1.35),
      h4: body(baseFontSize * 1.1, weight: FontWeight.w600, height: 1.4),
      h5: body(baseFontSize, weight: FontWeight.w600, height: 1.4),
      h6: body(
        baseFontSize * 0.9,
        weight: FontWeight.w600,
        height: 1.4,
      ).copyWith(color: tokens.fgMuted),
      a: TextStyle(color: tokens.accent, decoration: TextDecoration.underline),
      em: const TextStyle(fontStyle: FontStyle.italic),
      strong: const TextStyle(fontWeight: FontWeight.w700),
      del: const TextStyle(decoration: TextDecoration.lineThrough),
      code: code,
      // The code block itself is drawn by CodeBlockBuilder, which owns the
      // language label, the copy button and the raw-HTML box. What is left
      // here is the fallback, so a `pre` that somehow misses the builder is
      // still legible rather than invisible.
      codeblockDecoration: BoxDecoration(
        color: tokens.codeBg,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: body(baseFontSize).copyWith(color: tokens.fgMuted),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: tokens.border, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      listBullet: body(baseFontSize),
      listIndent: 24,
      tableHead: body(baseFontSize * 0.95, weight: FontWeight.w600),
      tableBody: body(baseFontSize * 0.95, height: 1.4),
      tableBorder: TableBorder.all(color: tokens.border),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      blockSpacing: 16,
      // textScaler is deliberately left alone so the reading zoom, which the
      // View menu applies through MediaQuery, reaches the document.
    );
  }
}

/// The scope map the code highlighter paints with.
///
/// Doc 01 settled that this is "a scope → `TextStyle` map derived from our own
/// doc 06 tokens", which is also why `flutter_highlight` and its ninety bundled
/// themes were dropped. Eight tokens cannot make a rainbow, and doc 06 asks to
/// keep the set small, so the map earns its distinctions from weight, slant and
/// the one loud colour rather than from new hues:
///
/// - comments recede to `fgMuted`, italic;
/// - the things a reader scans for — keywords, types, section names — take
///   weight;
/// - literals take `accent`, the only colour in the palette allowed to be loud.
///
/// A scope that is not here renders as the base style, which is what keeps an
/// unfamiliar grammar readable rather than invisible. If this ever wants real
/// hues, they are a change to doc 06's token set and should be argued there.
extension ReaderCodeTheme on ReaderStyle {
  /// See [ReaderStyle].
  static Map<String, TextStyle> of(ReaderTokens tokens) {
    final muted = TextStyle(color: tokens.fgMuted);
    final literal = TextStyle(color: tokens.accent);
    const bold = TextStyle(fontWeight: FontWeight.w600);

    return <String, TextStyle>{
      'comment': muted.copyWith(fontStyle: FontStyle.italic),
      'quote': muted.copyWith(fontStyle: FontStyle.italic),
      'doctag': muted.copyWith(fontWeight: FontWeight.w600),
      'meta': muted,
      'meta-keyword': muted.copyWith(fontWeight: FontWeight.w600),
      'meta-string': literal,
      'keyword': bold,
      'selector-tag': bold,
      'built_in': bold,
      'type': bold,
      'class': bold,
      'title': bold,
      'section': bold,
      'name': bold,
      'attr': muted,
      'attribute': muted,
      'property': muted,
      'string': literal,
      'number': literal,
      'literal': literal,
      'regexp': literal,
      'symbol': literal,
      'link': literal.copyWith(decoration: TextDecoration.underline),
      'addition': literal,
      'deletion': muted.copyWith(decoration: TextDecoration.lineThrough),
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'strong': bold,
    };
  }
}
