import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The chrome around the reader: which panels are showing, how wide the
/// sidebar is, and whether the window is full screen.
///
/// Exactly the `View` menu state that belongs to the *session*
/// (`docs/05_SESSION_AND_SETTINGS.md`). Zoom and theme used to live here too,
/// left over from the S4 prototype where everything was in memory — and they
/// also existed, unconnected, as `reading.fontScale` and `theme` in
/// `settings.json`, where doc 05 puts them. Two numbers for one preference is
/// a drift waiting to happen and a double-scale waiting to happen, so the
/// duplicates are gone rather than synchronised: settings own zoom and theme,
/// this owns panel geometry and full screen.
@immutable
class ChromeState {
  /// Creates a chrome state.
  const ChromeState({
    this.sidebarVisible = true,
    this.outlineVisible = true,
    this.sidebarWidth = 280,
    this.fullScreen = false,
  });

  /// Whether the file sidebar is showing.
  final bool sidebarVisible;

  /// Whether the outline panel is showing.
  final bool outlineVisible;

  /// Sidebar width in logical pixels, persisted in the session (doc 05).
  final double sidebarWidth;

  /// Whether the window is full screen.
  final bool fullScreen;

  /// Returns a copy with the given fields replaced.
  ChromeState copyWith({
    bool? sidebarVisible,
    bool? outlineVisible,
    double? sidebarWidth,
    bool? fullScreen,
  }) => ChromeState(
    sidebarVisible: sidebarVisible ?? this.sidebarVisible,
    outlineVisible: outlineVisible ?? this.outlineVisible,
    sidebarWidth: sidebarWidth ?? this.sidebarWidth,
    fullScreen: fullScreen ?? this.fullScreen,
  );
}

/// Drives [ChromeState] from the View menu and its shortcuts.
class ChromeController extends Notifier<ChromeState> {
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
  /// Full screen is deliberately not restored: it is per-launch state, not
  /// session geometry (`docs/05`).
  void restore({required double sidebarWidth, required bool outlineVisible}) =>
      state = state.copyWith(
        sidebarWidth: sidebarWidth,
        outlineVisible: outlineVisible,
      );
}

/// The chrome state provider.
final NotifierProvider<ChromeController, ChromeState> chromeProvider =
    NotifierProvider<ChromeController, ChromeState>(ChromeController.new);
