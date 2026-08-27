import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/settings/settings_store.dart';
import 'package:marklens/core/storage/json_store.dart';

/// `settings.json` as running state (`docs/05_SESSION_AND_SETTINGS.md`).
///
/// Until M2 there was no such thing: `settingsStoreProvider` exposed only the
/// *store*, `SettingsStore.save` had no caller anywhere in `lib/`, and the one
/// setting anything read — `recentLimit` — was fetched by loading the file off
/// disk synchronously on every session save. So `settings.json` was, in
/// practice, read-only at runtime, and every preference doc 05 describes was
/// unreachable.
///
/// This is the read path and the write path, and nothing else: the Settings
/// *UI* is M3 (doc 15). The View menu and the zoom shortcuts are the only
/// things that write today.
class AppSettingsController extends Notifier<AppSettings> {
  /// One press of Zoom In or Zoom Out (`docs/06_UI_UX.md`).
  static const double zoomStep = 0.1;

  /// How long changes are coalesced before reaching the disk.
  ///
  /// Doc 05 says settings are written on change with no debounce, on the
  /// grounds that they change when a person clicks something. That is true of
  /// a checkbox and false of zoom: holding `Ctrl+=` is a stream of changes,
  /// and each one would be a fsync-and-rename. A quarter of a second is below
  /// notice and turns a held key into one write (rule 7). Doc 05 amended.
  static const Duration writeDebounce = Duration(milliseconds: 250);

  SettingsStore? _store;
  Timer? _pending;
  AppSettings? _unwritten;
  JsonLoadOutcome _outcome = JsonLoadOutcome.ok;

  /// What happened the last time `settings.json` was read.
  ///
  /// Doc 05 asks for a one-time notice when the file was corrupt or came from
  /// a newer MarkLens. `SettingsStore` has always reported it and nothing has
  /// ever looked.
  JsonLoadOutcome get loadOutcome => _outcome;

  @override
  AppSettings build() {
    final store = ref.read(settingsStoreProvider);
    _store = store;
    // Cancelling is not enough: quitting a second after a change must not lose
    // it, the same guarantee the session store gives (doc 05).
    ref.onDispose(flush);

    final loaded = store.load();
    _outcome = loaded.outcome;
    return loaded.settings;
  }

  /// Light, dark, or follow the system.
  void setTheme(ThemePreference theme) => _apply(state.copyWith(theme: theme));

  /// Applies one zoom step: `1` in, `-1` out, `0` back to 100%.
  ///
  /// Zoom *is* `reading.fontScale` under the shorter name doc 06's View menu
  /// uses. It used to be a second number on `ChromeState` that was never read
  /// from or written to disk, beside this one that was never read at all.
  void zoomBy(int step) => setFontScale(
    switch (step) {
      0 => 1,
      final int s => state.reading.fontScale + s * zoomStep,
    },
  );

  /// Sets the reading scale directly, clamped to 50%–300%.
  void setFontScale(double scale) =>
      _apply(state.copyWith(reading: state.reading.copyWith(fontScale: scale)));

  /// Sets the reading column width, or `0` for the full window.
  void setContentMaxWidth(int width) => _apply(
    state.copyWith(reading: state.reading.copyWith(contentMaxWidth: width)),
  );

  /// Sets how the front-matter panel opens.
  void setFrontMatter(FrontMatterDisplay display) => _apply(
    state.copyWith(reading: state.reading.copyWith(frontMatter: display)),
  );

  /// Turns the file watcher on or off (`docs/07_FILES_AND_WATCH.md`).
  void setWatchEnabled({required bool enabled}) => _apply(
    state.copyWith(files: state.files.copyWith(watchEnabled: enabled)),
  );

  void _apply(AppSettings next) {
    state = next;
    _unwritten = next;
    _pending?.cancel();
    _pending = Timer(writeDebounce, flush);
  }

  /// Writes whatever is pending, now.
  ///
  /// Reads no provider, because it also runs while the scope is being disposed
  /// and `ref` is not usable there — the store is captured in [build] instead.
  void flush() {
    _pending?.cancel();
    _pending = null;
    final pending = _unwritten;
    if (pending == null) {
      return;
    }
    _unwritten = null;
    _store?.save(pending);
  }
}

/// The settings provider.
final NotifierProvider<AppSettingsController, AppSettings> settingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );
