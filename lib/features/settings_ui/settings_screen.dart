import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Settings (`Ctrl+,`, `docs/05_SESSION_AND_SETTINGS.md`).
///
/// Every field in the schema, and nothing that is not in it — there is no
/// hidden preference and no "advanced" pane. The ranges are the constants the
/// model already clamps by, so the widget cannot offer a value the loader
/// would silently pull back.
///
/// It lands after the images and update PRs deliberately: every switch here
/// has something behind it on the day it ships, which the settings that sat
/// unread from M1 to M3 did not.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  /// Shows it over [context].
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => const SettingsScreen(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Section(title: l10n.settingsSectionGeneral),
              _Choice<AppLanguage>(
                label: l10n.settingsLanguage,
                value: settings.language,
                values: AppLanguage.values,
                nameOf: (value) => switch (value) {
                  AppLanguage.system => l10n.settingsFollowSystem,
                  AppLanguage.en => 'English',
                  AppLanguage.vi => 'Tiếng Việt',
                  AppLanguage.ja => '日本語',
                },
                onChanged: controller.setLanguage,
              ),
              _Choice<ThemePreference>(
                label: l10n.menuTheme,
                value: settings.theme,
                values: ThemePreference.values,
                nameOf: (value) => switch (value) {
                  ThemePreference.system => l10n.menuThemeSystem,
                  ThemePreference.light => l10n.menuThemeLight,
                  ThemePreference.dark => l10n.menuThemeDark,
                },
                onChanged: controller.setTheme,
              ),
              _Switch(
                label: l10n.settingsRestoreSession,
                value: settings.restoreSession,
                onChanged: (value) =>
                    controller.setRestoreSession(restore: value),
              ),
              _Slider(
                label: l10n.settingsRecentLimit,
                value: settings.recentLimit.toDouble(),
                min: 0,
                max: AppSettings.maxRecentLimit.toDouble(),
                display: '${settings.recentLimit}',
                onChanged: (value) => controller.setRecentLimit(value.round()),
              ),

              _Section(title: l10n.settingsSectionReading),
              _Slider(
                label: l10n.settingsFontScale,
                value: settings.reading.fontScale,
                min: ReadingSettings.minFontScale,
                max: ReadingSettings.maxFontScale,
                display: '${(settings.reading.fontScale * 100).round()}%',
                onChanged: controller.setFontScale,
              ),
              _Slider(
                label: l10n.settingsContentWidth,
                // Zero is a value, not a minimum: it means full width. The
                // slider reaches it by stepping *below* the narrowest column,
                // which is the only place a "no limit" end can live on a
                // continuous control.
                value: settings.reading.contentMaxWidth == 0
                    ? ReadingSettings.minContentWidth.toDouble() - 1
                    : settings.reading.contentMaxWidth.toDouble(),
                min: ReadingSettings.minContentWidth.toDouble() - 1,
                max: ReadingSettings.maxContentWidth.toDouble(),
                display: settings.reading.contentMaxWidth == 0
                    ? l10n.settingsContentWidthFull
                    : '${settings.reading.contentMaxWidth}',
                onChanged: (value) => controller.setContentMaxWidth(
                  value.round() < ReadingSettings.minContentWidth
                      ? 0
                      : value.round(),
                ),
              ),
              _Choice<FrontMatterDisplay>(
                label: l10n.settingsFrontMatter,
                value: settings.reading.frontMatter,
                values: FrontMatterDisplay.values,
                nameOf: (value) => switch (value) {
                  FrontMatterDisplay.collapsed =>
                    l10n.settingsFrontMatterCollapsed,
                  FrontMatterDisplay.expanded =>
                    l10n.settingsFrontMatterExpanded,
                  FrontMatterDisplay.hidden => l10n.settingsFrontMatterHidden,
                },
                onChanged: controller.setFrontMatter,
              ),

              _Section(title: l10n.settingsSectionFiles),
              _Extensions(
                extensions: settings.files.extensions,
                onChanged: controller.setExtensions,
              ),
              _Slider(
                label: l10n.settingsFileCap,
                value: settings.files.fileCap.toDouble(),
                min: FilesSettings.minFileCap.toDouble(),
                max: FilesSettings.maxFileCap.toDouble(),
                display: '${settings.files.fileCap}',
                onChanged: (value) => controller.setFileCap(value.round()),
              ),
              _Switch(
                label: l10n.settingsWatch,
                value: settings.files.watchEnabled,
                onChanged: (value) =>
                    controller.setWatchEnabled(enabled: value),
              ),

              _Section(title: l10n.settingsSectionNetwork),
              _Switch(
                label: l10n.settingsRemoteImages,
                detail: l10n.settingsRemoteImagesDetail,
                value: settings.network.allowRemoteImages,
                onChanged: (value) =>
                    controller.setAllowRemoteImages(allow: value),
              ),
              _Switch(
                label: l10n.settingsUpdateCheck,
                detail: l10n.settingsUpdateCheckDetail,
                value: settings.network.updateCheck,
                onChanged: (value) => controller.setUpdateCheck(enabled: value),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          // No OK/Cancel pair: every change is applied and written as it is
          // made (debounced, doc 05), so there is nothing to confirm and
          // nothing a Cancel could undo without a second copy of the state.
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: ReaderTokens.of(context).accent,
      ),
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    subtitle: detail == null ? null : Text(detail!),
    value: value,
    onChanged: onChanged,
  );
}

/// A labelled row of radio-style choices.
///
/// A `SegmentedButton` rather than a dropdown: there are never more than four,
/// and doc 09 wants no fixed-width boxes around translated text — a segmented
/// row wraps its labels where a dropdown clips them.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) nameOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final option in values)
              ChoiceChip(
                label: Text(nameOf(option)),
                selected: option == value,
                onSelected: (selected) {
                  if (selected) {
                    onChanged(option);
                  }
                },
              ),
          ],
        ),
      ],
    ),
  );
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              display,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ReaderTokens.of(context).fgMuted,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          label: display,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// The extension registry, as a row of removable chips plus a field.
///
/// Editable because doc 07 says "user-editable in Settings", and the registry
/// gates folder scans, the dialog filter, drag-drop and CLI args alike — so
/// this one control decides what the whole app considers a document.
class _Extensions extends StatefulWidget {
  const _Extensions({required this.extensions, required this.onChanged});

  final List<String> extensions;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_Extensions> createState() => _ExtensionsState();
}

class _ExtensionsState extends State<_Extensions> {
  final TextEditingController _entry = TextEditingController();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _add() {
    final value = _entry.text.trim().replaceAll('.', '').toLowerCase();
    if (value.isEmpty || widget.extensions.contains(value)) {
      return;
    }
    widget.onChanged(<String>[...widget.extensions, value]);
    _entry.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.settingsExtensions,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final extension in widget.extensions)
                InputChip(
                  label: Text(extension),
                  onDeleted: () => widget.onChanged(
                    <String>[
                      for (final kept in widget.extensions)
                        if (kept != extension) kept,
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _entry,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.settingsExtensionsHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(onPressed: _add, child: Text(l10n.settingsAdd)),
            ],
          ),
        ],
      ),
    );
  }
}
