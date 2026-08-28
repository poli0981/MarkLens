import 'dart:ui';

import 'package:marklens/core/files/extension_registry.dart';

/// UI language (`docs/05_SESSION_AND_SETTINGS.md`).
enum AppLanguage {
  /// Follow the operating system, falling back to English.
  system,

  /// English.
  en,

  /// Vietnamese.
  vi,

  /// Japanese.
  ja,
}

/// What each language means to `MaterialApp.locale`.
///
/// An extension rather than a field on the enum, so `core/` stays free of
/// `package:flutter` (rule 3) — `Locale` comes from `dart:ui`, which is not
/// Flutter, but the mapping belongs beside the enum either way.
extension AppLanguageLocale on AppLanguage {
  /// The locale to force, or `null` to follow the platform.
  ///
  /// `system` is `null` on purpose: that is what makes Flutter resolve against
  /// the operating system's list and fall back to `supportedLocales.first`,
  /// which doc 09 says is English.
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.en => const Locale('en'),
    AppLanguage.vi => const Locale('vi'),
    AppLanguage.ja => const Locale('ja'),
  };
}

/// Light/dark preference.
///
/// Named for the preference rather than the theme, because `app/theme/` has an
/// `AppTheme` that builds the actual `ThemeData`. The two used to share a name
/// and never met; they meet as soon as the menu writes this one.
enum ThemePreference {
  /// Follow the operating system.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// How the front-matter panel opens.
///
/// Display only: the splitter lifts the block out of the document either way,
/// which is why this setting does not affect a parse and so does not belong in
/// the document cache key (`docs/04_MARKDOWN_PIPELINE.md`).
enum FrontMatterDisplay {
  /// Shown collapsed.
  collapsed,

  /// Shown expanded.
  expanded,

  /// Not shown at all.
  hidden,
}

/// Reading-surface preferences.
class ReadingSettings {
  /// Creates reading settings.
  const ReadingSettings({
    this.fontScale = 1,
    this.contentMaxWidth = 760,
    this.frontMatter = FrontMatterDisplay.collapsed,
  });

  /// Reads reading settings from [json], clamping anything out of range.
  factory ReadingSettings.fromJson(Map<String, Object?> json) {
    const fallback = ReadingSettings();
    final width = _readInt(json['contentMaxWidth'], fallback.contentMaxWidth);
    return ReadingSettings(
      fontScale: _clampDouble(
        _readDouble(json['fontScale'], fallback.fontScale),
        minFontScale,
        maxFontScale,
      ),
      // Zero is a value, not an out-of-range number: it means full width.
      contentMaxWidth: width == 0
          ? 0
          : width.clamp(minContentWidth, maxContentWidth),
      frontMatter: _readEnum(
        json['frontMatter'],
        FrontMatterDisplay.values,
        fallback.frontMatter,
      ),
    );
  }

  /// Smallest accepted [fontScale].
  static const double minFontScale = 0.5;

  /// Largest accepted [fontScale].
  static const double maxFontScale = 3;

  /// Narrowest accepted [contentMaxWidth], other than zero.
  static const int minContentWidth = 560;

  /// Widest accepted [contentMaxWidth].
  static const int maxContentWidth = 1200;

  /// Text scale, 0.5–3.0.
  final double fontScale;

  /// Column width in logical pixels, 560–1200, or `0` for full width.
  final int contentMaxWidth;

  /// How the front-matter panel opens.
  final FrontMatterDisplay frontMatter;

  /// Returns a copy with the given fields replaced.
  ///
  /// Clamps exactly as [ReadingSettings.fromJson] does. The constructor cannot
  /// clamp — it is `const`, and the defaults of [AppSettings] depend on that —
  /// so without this a zoom step could walk `fontScale` past its own bound and
  /// write it to disk, where the next load would silently pull it back.
  ReadingSettings copyWith({
    double? fontScale,
    int? contentMaxWidth,
    FrontMatterDisplay? frontMatter,
  }) {
    final width = contentMaxWidth ?? this.contentMaxWidth;
    return ReadingSettings(
      fontScale: _clampDouble(
        fontScale ?? this.fontScale,
        minFontScale,
        maxFontScale,
      ),
      // Zero stays zero: it means full width, not "below the minimum".
      contentMaxWidth: width == 0
          ? 0
          : width.clamp(minContentWidth, maxContentWidth),
      frontMatter: frontMatter ?? this.frontMatter,
    );
  }

  /// This object as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'fontScale': fontScale,
    'contentMaxWidth': contentMaxWidth,
    'frontMatter': frontMatter.name,
  };
}

/// Which files are opened, and how many.
class FilesSettings {
  /// Creates file settings.
  const FilesSettings({
    this.extensions = ExtensionRegistry.defaultExtensions,
    this.fileCap = 1000,
    this.watchEnabled = true,
  });

  /// Reads file settings from [json], clamping anything out of range.
  factory FilesSettings.fromJson(Map<String, Object?> json) {
    const fallback = FilesSettings();
    final extensions = ExtensionRegistry(
      _readStrings(json['extensions'], fallback.extensions),
    ).extensions;
    return FilesSettings(
      // An empty list would open nothing at all, which is never what the user
      // meant; it falls back rather than locking them out of their own files.
      extensions: extensions.isEmpty ? fallback.extensions : extensions,
      fileCap: _readInt(
        json['fileCap'],
        fallback.fileCap,
      ).clamp(minFileCap, maxFileCap),
      watchEnabled: _readBool(json['watchEnabled'], fallback.watchEnabled),
    );
  }

  /// Smallest accepted [fileCap].
  static const int minFileCap = 100;

  /// Largest accepted [fileCap].
  static const int maxFileCap = 2000;

  /// Extensions the app opens, without dots.
  final List<String> extensions;

  /// How many entries one scan may open, 100–2000.
  final int fileCap;

  /// Whether the watcher runs.
  final bool watchEnabled;

  /// Returns a copy with the given fields replaced, clamped as `fromJson`
  /// clamps.
  FilesSettings copyWith({
    List<String>? extensions,
    int? fileCap,
    bool? watchEnabled,
  }) {
    final next = extensions ?? this.extensions;
    return FilesSettings(
      extensions: next.isEmpty ? const FilesSettings().extensions : next,
      fileCap: (fileCap ?? this.fileCap).clamp(minFileCap, maxFileCap),
      watchEnabled: watchEnabled ?? this.watchEnabled,
    );
  }

  /// This object as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'extensions': extensions,
    'fileCap': fileCap,
    'watchEnabled': watchEnabled,
  };
}

/// The two settings that can cause any network traffic at all.
///
/// Both default to the quiet answer. There is no third: MarkLens has no
/// telemetry and no analytics, ever (CLAUDE.md rule 5).
class NetworkSettings {
  /// Creates network settings.
  const NetworkSettings({
    this.allowRemoteImages = false,
    this.updateCheck = true,
  });

  /// Reads network settings from [json].
  factory NetworkSettings.fromJson(Map<String, Object?> json) {
    const fallback = NetworkSettings();
    return NetworkSettings(
      allowRemoteImages: _readBool(
        json['allowRemoteImages'],
        fallback.allowRemoteImages,
      ),
      updateCheck: _readBool(json['updateCheck'], fallback.updateCheck),
    );
  }

  /// Whether `http(s)` images load, rather than showing a blocked placeholder.
  final bool allowRemoteImages;

  /// Whether the GitHub Releases version check runs.
  final bool updateCheck;

  /// Returns a copy with the given fields replaced.
  NetworkSettings copyWith({bool? allowRemoteImages, bool? updateCheck}) =>
      NetworkSettings(
        allowRemoteImages: allowRemoteImages ?? this.allowRemoteImages,
        updateCheck: updateCheck ?? this.updateCheck,
      );

  /// This object as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'allowRemoteImages': allowRemoteImages,
    'updateCheck': updateCheck,
  };
}

/// Everything in `settings.json` (`docs/05_SESSION_AND_SETTINGS.md`).
///
/// Reading is total: any field that is missing, of the wrong type or out of
/// range falls back to its default rather than failing the load. A settings
/// file someone hand-edited badly must not stop the app opening (rule 9).
class AppSettings {
  /// Creates settings.
  const AppSettings({
    this.language = AppLanguage.system,
    this.theme = ThemePreference.system,
    this.restoreSession = true,
    this.recentLimit = 20,
    this.reading = const ReadingSettings(),
    this.files = const FilesSettings(),
    this.network = const NetworkSettings(),
  });

  /// Reads settings from [json].
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const fallback = AppSettings();
    return AppSettings(
      language: _readEnum(
        json['language'],
        AppLanguage.values,
        AppLanguage.system,
      ),
      theme: _readEnum(
        json['theme'],
        ThemePreference.values,
        ThemePreference.system,
      ),
      restoreSession: _readBool(
        json['restoreSession'],
        fallback.restoreSession,
      ),
      recentLimit: _readInt(
        json['recentLimit'],
        fallback.recentLimit,
      ).clamp(0, maxRecentLimit),
      reading: ReadingSettings.fromJson(_readMap(json['reading'])),
      files: FilesSettings.fromJson(_readMap(json['files'])),
      network: NetworkSettings.fromJson(_readMap(json['network'])),
    );
  }

  /// The schema version this code writes.
  static const int schemaVersion = 1;

  /// Largest accepted [recentLimit].
  ///
  /// Not in doc 05, which gives no range for it. A bound is needed anyway,
  /// because the recent list lives in `session.json` and an unbounded limit
  /// makes that file grow without end. Recorded in doc 05 with this reason.
  static const int maxRecentLimit = 200;

  /// UI language.
  final AppLanguage language;

  /// Light/dark preference.
  final ThemePreference theme;

  /// Whether the previous session is restored at startup.
  final bool restoreSession;

  /// How many entries the recent list keeps, 0–[maxRecentLimit].
  final int recentLimit;

  /// Reading-surface preferences.
  final ReadingSettings reading;

  /// Which files are opened, and how many.
  final FilesSettings files;

  /// The two network switches.
  final NetworkSettings network;

  /// Returns a copy with the given fields replaced.
  ///
  /// A sub-object that is not named comes back as the *same instance*, which is
  /// what lets `ref.watch(settingsProvider.select((s) => s.reading))` skip a
  /// rebuild when something unrelated changed.
  AppSettings copyWith({
    AppLanguage? language,
    ThemePreference? theme,
    bool? restoreSession,
    int? recentLimit,
    ReadingSettings? reading,
    FilesSettings? files,
    NetworkSettings? network,
  }) => AppSettings(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    restoreSession: restoreSession ?? this.restoreSession,
    recentLimit: (recentLimit ?? this.recentLimit).clamp(0, maxRecentLimit),
    reading: reading ?? this.reading,
    files: files ?? this.files,
    network: network ?? this.network,
  );

  /// This object as JSON, including the schema version.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': schemaVersion,
    'language': language.name,
    'theme': theme.name,
    'restoreSession': restoreSession,
    'recentLimit': recentLimit,
    'reading': reading.toJson(),
    'files': files.toJson(),
    'network': network.toJson(),
  };
}

Map<String, Object?> _readMap(Object? value) =>
    value is Map<String, Object?> ? value : const <String, Object?>{};

bool _readBool(Object? value, bool fallback) =>
    value is bool ? value : fallback;

int _readInt(Object? value, int fallback) => switch (value) {
  final int i => i,
  final double d when d.isFinite => d.round(),
  _ => fallback,
};

double _readDouble(Object? value, double fallback) => switch (value) {
  final double d when d.isFinite => d,
  final int i => i.toDouble(),
  _ => fallback,
};

double _clampDouble(double value, double low, double high) =>
    value < low ? low : (value > high ? high : value);

List<String> _readStrings(Object? value, List<String> fallback) =>
    value is List ? <String>[...value.whereType<String>()] : fallback;

T _readEnum<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! String) {
    return fallback;
  }
  for (final candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  return fallback;
}
