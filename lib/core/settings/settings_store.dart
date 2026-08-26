import 'dart:io';

import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/storage/json_store.dart';

/// Loaded settings, and what happened while loading them.
typedef SettingsLoad = ({AppSettings settings, JsonLoadOutcome outcome});

/// Reads and writes `settings.json`.
///
/// Takes its `directory` as a constructor argument and never calls
/// `path_provider`, which is a Flutter plugin (rule 3, `docs/05`). Written on
/// change rather than debounced — settings change when a person clicks
/// something, which is rare, unlike the scroll position the session tracks.
class SettingsStore {
  /// Creates a store writing into [directory].
  SettingsStore({required Directory directory})
    : _store = JsonStore(directory: directory, name: 'settings');

  final JsonStore _store;

  /// The file this store owns, for tests and for the About screen.
  File get file => _store.file;

  /// Reads the settings.
  ///
  /// Always returns usable settings. A missing file is a first run; a corrupt
  /// one is set aside and defaults are used; a file from a **newer** MarkLens
  /// is backed up rather than read, so a downgrade cannot quietly rewrite a
  /// schema it does not know (doc 05, migration policy).
  SettingsLoad load() {
    final loaded = _store.load();
    if (loaded.outcome != JsonLoadOutcome.ok) {
      return (settings: const AppSettings(), outcome: loaded.outcome);
    }

    final version = loaded.data['version'];
    if (version is int && version > AppSettings.schemaVersion) {
      _store.quarantine('bak');
      return (
        settings: const AppSettings(),
        outcome: JsonLoadOutcome.futureVersion,
      );
    }

    // Older versions migrate forward here as they appear. There is only v1, so
    // there is nothing to migrate yet — and a file with no version at all is
    // read as v1 rather than discarded, since v1 is the only shape that has
    // ever been written.
    return (
      settings: AppSettings.fromJson(loaded.data),
      outcome: JsonLoadOutcome.ok,
    );
  }

  /// Writes [settings], atomically. Returns whether the write landed.
  bool save(AppSettings settings) => _store.save(settings.toJson());
}
