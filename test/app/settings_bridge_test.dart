/// Settings reach the UI, and changes reach the disk
/// (`docs/05_SESSION_AND_SETTINGS.md`).
///
/// Before M2 neither half existed: `settingsStoreProvider` exposed only the
/// store, `SettingsStore.save` had no caller in `lib/`, and zoom and theme each
/// lived twice — once in `settings.json` where nothing read them, once on
/// `ChromeState` where nothing wrote them. Every test here would have failed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/features/reader/front_matter_panel.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory config;

  String at(String name) => '${config.path}${Platform.pathSeparator}$name';

  File settingsFile() => File(at('settings.json'));

  Map<String, Object?> readSettings() =>
      jsonDecode(settingsFile().readAsStringSync()) as Map<String, Object?>;

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_settings_');
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        configDirectoryProvider.overrideWithValue(config),
        windowLinkProvider.overrideWithValue(const NoWindowLink()),
        sessionStoreProvider.overrideWithValue(
          SessionStore(
            directory: config,
            debounce: const Duration(milliseconds: 10),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  /// Lets the settings debounce expire so the write actually lands.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(AppSettingsController.writeDebounce);
    await tester.pumpAndSettle();
  }

  group('a preference survives the app', () {
    testWidgets('zoom is written to settings.json', (tester) async {
      final container = await pumpShell(tester);
      container.read(settingsProvider.notifier)
        ..zoomBy(1)
        ..zoomBy(1);
      await settle(tester);

      final reading = readSettings()['reading']! as Map<String, Object?>;
      expect(
        reading['fontScale'],
        closeTo(1.2, 1e-9),
        reason: 'two steps of 0.1 from 1.0',
      );
    });

    testWidgets('and is applied on the next launch', (tester) async {
      settingsFile().writeAsStringSync(
        jsonEncode(
          const AppSettings(
            reading: ReadingSettings(fontScale: 1.5),
          ).toJson(),
        ),
      );

      final container = await pumpShell(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(container.read(settingsProvider).reading.fontScale, 1.5);
      expect(
        tester
            .widget<Text>(find.text(l10n.emptyStateDropHint))
            .textScaler
            ?.scale(10),
        15.0,
        reason: 'the stored scale is what the reading surface opens at',
      );
    });

    testWidgets('a held zoom key is one write, not thirty', (tester) async {
      final container = await pumpShell(tester);
      final controller = container.read(settingsProvider.notifier);
      for (var i = 0; i < 30; i++) {
        controller.zoomBy(1);
      }
      expect(
        settingsFile().existsSync(),
        isFalse,
        reason: 'nothing reaches the disk while the key is still down',
      );

      await settle(tester);
      expect(readSettings(), isNotEmpty);
    });

    testWidgets('the theme is written and re-read', (tester) async {
      final container = await pumpShell(tester);
      container.read(settingsProvider.notifier).setTheme(ThemePreference.dark);
      await settle(tester);

      expect(readSettings()['theme'], 'dark');
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
        reason: 'the stored preference drives MaterialApp, not a second copy',
      );
    });
  });

  group('reading preferences finally reach the reader', () {
    Future<ProviderContainer> openDocument(WidgetTester tester) async {
      final path = at('doc.md');
      File(path).writeAsStringSync('---\ntitle: Kept\n---\n\n# Body\n');
      final container = await pumpShell(tester);
      container.read(openSetProvider.notifier).openPaths(<String>[path]);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('front matter can be hidden', (tester) async {
      final container = await openDocument(tester);
      expect(find.byKey(const Key('reader-front-matter')), findsOneWidget);

      container
          .read(settingsProvider.notifier)
          .setFrontMatter(FrontMatterDisplay.hidden);
      await settle(tester);

      expect(
        find.byKey(const Key('reader-front-matter')),
        findsNothing,
        reason: 'reading.frontMatter had never been passed to the reader',
      );
    });

    testWidgets('front matter can be expanded from the stored setting', (
      tester,
    ) async {
      final container = await openDocument(tester);
      container
          .read(settingsProvider.notifier)
          .setFrontMatter(FrontMatterDisplay.expanded);
      await settle(tester);

      expect(find.text('Kept'), findsOneWidget);
    });

    testWidgets('the column narrows and widens with the setting', (
      tester,
    ) async {
      final container = await openDocument(tester);

      Future<double> widthAt(int maxWidth) async {
        container.read(settingsProvider.notifier).setContentMaxWidth(maxWidth);
        await settle(tester);
        return tester.getSize(find.byType(FrontMatterPanel)).width;
      }

      // The reader area is narrower than the 760 default here — the sidebar
      // and outline take their share — so the default is not what is being
      // measured. 560 is the doc 05 minimum and genuinely binds.
      final narrow = await widthAt(ReadingSettings.minContentWidth);
      final full = await widthAt(0);

      expect(
        full,
        greaterThan(narrow),
        reason: 'zero means full width, not a value below the minimum (doc 05)',
      );
    });
  });

  group('a settings file that cannot be read', () {
    testWidgets('falls back to defaults and says so once', (tester) async {
      settingsFile().writeAsStringSync('{ this is not json');

      final container = await pumpShell(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        container.read(settingsProvider).reading.fontScale,
        1.0,
        reason: 'a bad file must not stop the app opening (rule 9)',
      );
      expect(find.text(l10n.settingsNotRestored), findsOneWidget);
      expect(
        config
            .listSync()
            .where((e) => e.path.contains('settings.json.corrupt-'))
            .length,
        1,
        reason: 'the evidence is set aside, never deleted (doc 05)',
      );
    });
  });
}
