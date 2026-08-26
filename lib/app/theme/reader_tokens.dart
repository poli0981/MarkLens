import 'package:flutter/material.dart';

/// The small, fixed set of colours everything MarkLens draws is made of.
///
/// Doc 06 names them and says to finalize them at M1, keeping the set small:
/// `bg`, `bgAlt`, `fg`, `fgMuted`, `accent`, `codeBg`, `border`, `selection`.
/// Eight is the whole palette — a ninth needs an argument, because the reason
/// this set is small is that a reading surface with many colours is a reading
/// surface that fights the document.
///
/// Carried as a `ThemeExtension` so every widget reads them the same way,
/// through `Theme.of(context)`, and so a swap of the renderer cannot quietly
/// change the app's colours (`docs/02_ARCHITECTURE.md`, "The seam").
///
/// **Contrast is measured, not eyeballed.** `test/app/reader_tokens_test.dart`
/// computes the WCAG ratios and fails if a colour drops below the threshold
/// for its job, in either theme. Change a value there and the test tells you
/// whether it is still readable.
@immutable
class ReaderTokens extends ThemeExtension<ReaderTokens> {
  /// Creates a token set.
  const ReaderTokens({
    required this.bg,
    required this.bgAlt,
    required this.fg,
    required this.fgMuted,
    required this.accent,
    required this.codeBg,
    required this.border,
    required this.selection,
  });

  /// The light palette.
  static const ReaderTokens light = ReaderTokens(
    bg: Color(0xFFFFFFFF),
    bgAlt: Color(0xFFF4F6F8),
    fg: Color(0xFF1B1F24),
    fgMuted: Color(0xFF57606D),
    accent: Color(0xFF0B5FCC),
    codeBg: Color(0xFFF0F3F6),
    border: Color(0xFFD3D9E0),
    selection: Color(0xFFBBD6FB),
  );

  /// The dark palette.
  static const ReaderTokens dark = ReaderTokens(
    bg: Color(0xFF14171C),
    bgAlt: Color(0xFF1B1F26),
    fg: Color(0xFFE6E9EE),
    fgMuted: Color(0xFFA6AFBC),
    accent: Color(0xFF7FB3F7),
    codeBg: Color(0xFF1E232B),
    border: Color(0xFF333B45),
    selection: Color(0xFF2F4E7A),
  );

  /// The reading surface.
  final Color bg;

  /// Panels and other surfaces that sit beside the document: the sidebar, the
  /// outline, the status bar, the front-matter panel.
  final Color bgAlt;

  /// Body text.
  final Color fg;

  /// Secondary text — the status bar, a code block's language label, the
  /// keys in the front-matter panel.
  final Color fgMuted;

  /// Links, the current outline entry, and the highlight pulse on an anchor
  /// jump. The only colour in the set that is allowed to be loud.
  final Color accent;

  /// Behind fenced code, and behind the "Raw HTML (not rendered)" box.
  final Color codeBg;

  /// Hairlines: panel edges, table rules, the notice bar's underline.
  final Color border;

  /// Text selection.
  final Color selection;

  /// The tokens for [context], or the light set if none were installed.
  ///
  /// The fallback exists so a widget test can pump a bare `MaterialApp`
  /// without every read becoming a null check.
  static ReaderTokens of(BuildContext context) =>
      Theme.of(context).extension<ReaderTokens>() ?? light;

  @override
  ReaderTokens copyWith({
    Color? bg,
    Color? bgAlt,
    Color? fg,
    Color? fgMuted,
    Color? accent,
    Color? codeBg,
    Color? border,
    Color? selection,
  }) => ReaderTokens(
    bg: bg ?? this.bg,
    bgAlt: bgAlt ?? this.bgAlt,
    fg: fg ?? this.fg,
    fgMuted: fgMuted ?? this.fgMuted,
    accent: accent ?? this.accent,
    codeBg: codeBg ?? this.codeBg,
    border: border ?? this.border,
    selection: selection ?? this.selection,
  );

  @override
  ReaderTokens lerp(covariant ReaderTokens? other, double t) {
    if (other == null) {
      return this;
    }
    return ReaderTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      bgAlt: Color.lerp(bgAlt, other.bgAlt, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      fgMuted: Color.lerp(fgMuted, other.fgMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
    );
  }
}
