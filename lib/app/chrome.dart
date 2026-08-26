import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The chrome around the reader: which panels are showing, the reading zoom,
/// the theme, and whether the window is full screen.
///
/// All of it is `View` menu state (`docs/06_UI_UX.md`) and all of it persists
/// to `session.json` / `settings.json` at M1 — for the S4 prototype it lives in
/// memory, which is enough to tell whether the menu and its shortcuts feel
/// right.
@immutable
class ChromeState {
  /// Creates a chrome state.
  const ChromeState({
    this.sidebarVisible = true,
    this.outlineVisible = true,
    this.sidebarWidth = 280,
    this.zoom = 1,
    this.themeMode = ThemeMode.system,
    this.fullScreen = false,
  });

  /// Whether the file sidebar is showing.
  final bool sidebarVisible;

  /// Whether the outline panel is showing.
  final bool outlineVisible;

  /// Sidebar width in logical pixels, persisted in the session (doc 05).
  final double sidebarWidth;

  /// Reading zoom, clamped to 50%–300% (`docs/06_UI_UX.md`).
  final double zoom;

  /// Light, dark, or follow the system.
  final ThemeMode themeMode;

  /// Whether the window is full screen.
  final bool fullScreen;

  /// Returns a copy with the given fields replaced.
  ChromeState copyWith({
    bool? sidebarVisible,
    bool? outlineVisible,
    double? sidebarWidth,
    double? zoom,
    ThemeMode? themeMode,
    bool? fullScreen,
  }) => ChromeState(
    sidebarVisible: sidebarVisible ?? this.sidebarVisible,
    outlineVisible: outlineVisible ?? this.outlineVisible,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    zoom: zoom ?? this.zoom,
    themeMode: themeMode ?? this.themeMode,
    fullScreen: fullScreen ?? this.fullScreen,
  );
}

/// Drives [ChromeState] from the View menu and its shortcuts.
class ChromeController extends Notifier<ChromeState> {
  /// Zoom bounds from `docs/06_UI_UX.md`: 50%–300%.
  static const double minZoom = 0.5;

  /// See [minZoom].
  static const double maxZoom = 3;

  /// One press of Zoom In or Zoom Out.
  static const double zoomStep = 0.1;

  @override
  ChromeState build() => const ChromeState();

  /// Shows or hides the sidebar.
  void toggleSidebar() =>
      state = state.copyWith(sidebarVisible: !state.sidebarVisible);

  /// Shows or hides the outline panel.
  void toggleOutline() =>
      state = state.copyWith(outlineVisible: !state.outlineVisible);

  /// Enters or leaves full screen.
  void toggleFullScreen() =>
      state = state.copyWith(fullScreen: !state.fullScreen);

  /// Puts back what the session remembered.
  ///
  /// Only the parts the session stores. Zoom, theme and full screen are
  /// settings or per-launch state, not session geometry (`docs/05`).
  void restore({required double sidebarWidth, required bool outlineVisible}) =>
      state = state.copyWith(
        sidebarWidth: sidebarWidth,
        outlineVisible: outlineVisible,
      );

  /// Sets the colour theme.
  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  /// Applies one zoom step: `1` in, `-1` out, `0` back to 100%.
  void zoomBy(int step) {
    final next = switch (step) {
      0 => 1.0,
      final int s => state.zoom + s * zoomStep,
    };
    state = state.copyWith(zoom: next.clamp(minZoom, maxZoom));
  }
}

/// The chrome state provider.
final NotifierProvider<ChromeController, ChromeState> chromeProvider =
    NotifierProvider<ChromeController, ChromeState>(ChromeController.new);
