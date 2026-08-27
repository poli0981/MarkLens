import 'package:flutter/material.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';

/// Builds the two `ThemeData`s from the doc 06 tokens.
///
/// Material's own colour scheme is derived *from* the tokens rather than the
/// other way round, so there is one source of colour in the app and a Material
/// default cannot quietly appear next to a token colour and look almost right.
abstract final class AppTheme {
  /// The light theme.
  static ThemeData get light => _from(ReaderTokens.light, Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _from(ReaderTokens.dark, Brightness.dark);

  static ThemeData _from(ReaderTokens tokens, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accent,
          brightness: brightness,
        ).copyWith(
          surface: tokens.bg,
          onSurface: tokens.fg,
          surfaceContainerHighest: tokens.bgAlt,
          outlineVariant: tokens.border,
          primary: tokens.accent,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.bg,
      dividerColor: tokens.border,
      extensions: <ThemeExtension<Object?>>[tokens],
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: tokens.selection,
        cursorColor: tokens.accent,
      ),
    );
  }
}

/// The Flutter `ThemeMode` a stored [ThemePreference] means.
///
/// An exhaustive switch with no default, so a fourth preference cannot be added
/// without deciding what it looks like — the same shape the notice-kind mapping
/// uses (`docs/06_UI_UX.md`).
extension ThemePreferenceMode on ThemePreference {
  /// This preference as Flutter expresses it.
  ThemeMode get mode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}
