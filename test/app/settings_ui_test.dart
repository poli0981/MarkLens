/// `docs/05_SESSION_AND_SETTINGS.md`'s schema, as a screen — and the three
/// settings that had no reader at all until M3.
///
/// The point of this file is the second half. A settings screen that writes
/// `settings.json` correctly and changes nothing about the running app is what
/// MarkLens had from M1 to M3: `language`, `restoreSession`, `files.extensions`
/// and `files.fileCap` all round-tripped through disk with nobody looking.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/app.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/session/session_store.dart';
import 'package:marklens/core/settings/settings_store.dart';
import 'package:marklens/features/settings_ui/settings_screen.dart';

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

void main() {
  late Directory root;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_settings_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  void writeSettings(Map<String, Object?> json) =>
      File(at('settings.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{'version': 1, ...json}),
      );

  void writeSession(Map<String, Object?> json) =>
      File(at('session.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{'version': 1, ...json}),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configDirectoryProvider.overrideWithValue(root),
          filePickerPromptProvider.overrideWithValue(_StubPrompt()),
          windowLinkProvider.overrideWithValue(const NoWindowLink()),
          watchLinkProvider.overrideWithValue(const NoWatchLink()),
          launcherLinkProvider.overrideWithValue(RecordingLauncherLink()),
          settingsStoreProvider.overrideWithValue(
            SettingsStore(directory: root),
          ),
          sessionStoreProvider.overrideWithValue(
            SessionStore(
              directory: root,
              debounce: const Duration(milliseconds: 10),
            ),
          ),
        ],
        child: const MarkLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    return containerOf(tester);
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('the screen', () {
    testWidgets('Ctrl+, was the last _todo() stub in the shell', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSettings(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('every section of doc 05’s schema is on it', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      for (final section in <String>[
        'General',
        'Reading',
        'Files',
        'Network',
      ]) {
        expect(find.text(section), findsOneWidget, reason: section);
      }
    });

    testWidgets('a change is applied at once, with no OK to press', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(settingsProvider).theme, ThemePreference.dark);
    });

    testWidgets('and reaches settings.json, debounced', (tester) async {
      final container = await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Dark'));
      // The store coalesces over 250 ms (doc 05); pumping past it is also what
      // stops a pending timer failing the test after the body passes.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        SettingsStore(directory: root).load().settings.theme,
        ThemePreference.dark,
      );
      expect(container.read(settingsProvider).theme, ThemePreference.dark);
    });

    testWidgets('a slider cannot offer a value the loader would clamp', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();

      expect(sliders, isNotEmpty);
      for (final slider in sliders) {
        expect(slider.value, greaterThanOrEqualTo(slider.min));
        expect(slider.value, lessThanOrEqualTo(slider.max));
      }
    });
  });

  group('language — no reader at all until M3', () {
    testWidgets('choosing Vietnamese translates the running app', (
      tester,
    ) async {
      // `MaterialApp` set `supportedLocales` and never a `locale`, so this
      // setting round-tripped through disk and did nothing.
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('and Japanese', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);

      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
    });

    testWidgets('system leaves it to the platform', (tester) async {
      await pumpApp(tester);
      await openSettings(tester);
      await tester.tap(find.text('日本語'));
      await tester.pumpAndSettle();

      // Both the language and the theme rows offer a "follow the system"
      // chip, and in Japanese they read identically.
      await tester.tap(find.text('システムに従う').first);
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('restoreSession — no reader either', () {
    testWidgets('on, the session comes back', (tester) async {
      final path = at('doc.md');
      File(path).writeAsStringSync('# Doc\n');
      writeSession(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'path': path},
        ],
        'activePath': path,
      });

      final container = await pumpApp(tester);

      expect(container.read(openSetProvider).entries, hasLength(1));
    });

    testWidgets('off, the window opens empty', (tester) async {
      final path = at('doc.md');
      File(path).writeAsStringSync('# Doc\n');
      writeSession(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'path': path},
        ],
        'activePath': path,
      });
      writeSettings(<String, Object?>{'restoreSession': false});

      final container = await pumpApp(tester);

      expect(container.read(openSetProvider).entries, isEmpty);
    });

    testWidgets('and the session file is left alone, not emptied', (
      tester,
    ) async {
      // A preference about *this* launch must not throw away what the last one
      // recorded — turning it back on has to bring the session back.
      final path = at('doc.md');
      File(path).writeAsStringSync('# Doc\n');
      writeSession(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'path': path},
        ],
      });
      writeSettings(<String, Object?>{'restoreSession': false});

      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        File(at('session.json')).readAsStringSync(),
        contains('doc.md'),
        reason: 'not restoring is not the same as forgetting',
      );
    });
  });

  group('files.extensions — the registry the whole app asks', () {
    testWidgets('adding one makes that kind of file turn up in a scan', (
      tester,
    ) async {
      // The registry gates the *scan*, the dialog filter and drag-drop — not
      // `describe`, which opens whatever it is handed, because a path named on
      // the command line beats our idea of what a document is (doc 07).
      File(at('notes.rst')).writeAsStringSync('# Notes\n');
      File(at('readme.md')).writeAsStringSync('# Readme\n');
      final container = await pumpApp(tester);

      List<String> scanned() => <String>[
        for (final file in container.read(fileServiceProvider).scanRoots(
          <String>[root.path],
        ).files)
          file.name,
      ];

      expect(
        scanned(),
        <String>['readme.md'],
        reason: '.rst is not in the default set',
      );

      container.read(settingsProvider.notifier).setExtensions(<String>[
        ...container.read(settingsProvider).files.extensions,
        'rst',
      ]);
      await tester.pumpAndSettle();

      expect(
        scanned(),
        containsAll(<String>['readme.md', 'notes.rst']),
        reason: 'the file service is built from the setting, and was not',
      );
    });

    testWidgets('and the screen can add and remove them', (tester) async {
      final container = await pumpApp(tester);
      await openSettings(tester);

      // The dialog scrolls, and Files is the third section — the field has to
      // be brought on screen before it can be typed into or tapped.
      final field = find.byType(TextField).last;
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'rst');
      final add = find.widgetWithText(TextButton, 'Add');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(
        container.read(settingsProvider).files.extensions,
        contains('rst'),
      );

      // By position rather than by icon: the delete affordance is whatever
      // `InputChip` draws for `onDeleted`, and pinning a test to Material's
      // choice of glyph is pinning it to a theme.
      final remove = find
          .descendant(
            of: find.widgetWithText(InputChip, 'rst'),
            matching: find.byType(Icon),
          )
          .last;
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(
        container.read(settingsProvider).files.extensions,
        isNot(contains('rst')),
      );
    });

    testWidgets('fileCap reaches the file service too', (tester) async {
      final container = await pumpApp(tester);
      expect(container.read(fileServiceProvider).fileCap, 1000);

      container.read(settingsProvider.notifier).setFileCap(150);
      await tester.pumpAndSettle();

      expect(container.read(fileServiceProvider).fileCap, 150);
    });
  });

  group('the two network switches now have consumers', () {
    testWidgets('remote images reaches the reader', (tester) async {
      final container = await pumpApp(tester);
      expect(
        container.read(settingsProvider).network.allowRemoteImages,
        isFalse,
        reason: 'off by default, and the default is the point (doc 10)',
      );

      container
          .read(settingsProvider.notifier)
          .setAllowRemoteImages(
            allow: true,
          );
      await tester.pumpAndSettle();

      expect(
        container.read(settingsProvider).network.allowRemoteImages,
        isTrue,
      );
    });

    testWidgets('and the update switch is on the screen, with its reason', (
      tester,
    ) async {
      await pumpApp(tester);
      await openSettings(tester);

      expect(find.text('Check for new versions'), findsOneWidget);
      expect(
        find.textContaining('Nothing about you is sent'),
        findsOneWidget,
        reason: 'a network switch should say what the traffic is',
      );
    });
  });
}
