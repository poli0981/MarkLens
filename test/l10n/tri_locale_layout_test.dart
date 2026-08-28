/// `docs/09_I18N.md`'s M3 definition of done: "menu bar tested in all three
/// locales", and the layout tolerance behind it — "Vietnamese runs ~20–30%
/// longer than English; Japanese is denser but taller. UI must tolerate both:
/// no fixed-width buttons around text".
///
/// Every surface M3 added is chrome full of translated text, and the M1 visual
/// pass is the reason this exists as a test: eight defects, every one of them
/// layout or copy, none caught by 716 behavioural tests. Flutter reports a
/// `RenderFlex` overflow as an exception in a test binding, so a surface that
/// fits in English and bursts in Vietnamese *is* catchable — just not by any
/// assertion about behaviour.
///
/// It cannot see typography, spacing or whether a thing reads well. That stays
/// the maintainer's pass against the real binary (doc 15).
library;

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
import 'package:marklens/core/update/update_service.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

class _StubPrompt implements FilePickerPrompt {
  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async =>
      const <String>[];

  @override
  Future<String?> pickFolder() async => null;
}

class _StubTransport implements UpdateTransport {
  @override
  Future<String?> fetchLatestRelease(Uri endpoint) async =>
      '{"tag_name":"v9.9.9","html_url":"https://example.com/r",'
      '"draft":false,"prerelease":false}';
}

/// Every locale doc 09 makes first class.
const List<AppLanguage> everyLocale = <AppLanguage>[
  AppLanguage.en,
  AppLanguage.vi,
  AppLanguage.ja,
];

void main() {
  late Directory root;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_locale_');
    File(at('README.md')).writeAsStringSync(
      '# Title\n\nA paragraph with a [link](https://example.com).\n',
    );
    File(at('OTHER.md')).writeAsStringSync('# Other\n\nMore text.\n');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );

  /// Pumps the whole app in [language] at [size], with two documents open.
  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    AppLanguage language, {
    required Size size,
  }) async {
    tester.view
      ..physicalSize = size
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
          saveFilePromptProvider.overrideWithValue(StubSaveFilePrompt()),
          updateServiceProvider.overrideWithValue(
            UpdateService(transport: _StubTransport()),
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

    final container = containerOf(tester);
    container.read(settingsProvider.notifier).setLanguage(language);
    container.read(openSetProvider.notifier).openPaths(<String>[
      at('README.md'),
      at('OTHER.md'),
    ]);
    await tester.pumpAndSettle();
    return container;
  }

  /// Fails with the overflow, if the last frame produced one.
  void expectNoOverflow(WidgetTester tester, String what) {
    final thrown = tester.takeException();
    expect(
      thrown,
      isNull,
      reason: '$what does not fit — $thrown',
    );
  }

  /// A window narrow enough to be honest, and one that is comfortable.
  ///
  /// 1024×720 is the floor a 1366×768 laptop leaves after chrome, and it is
  /// where a Vietnamese label 30% longer than its English original runs out of
  /// room first.
  const sizes = <String, Size>{
    'narrow': Size(1024, 720),
    'wide': Size(1440, 900),
  };

  for (final language in everyLocale) {
    final name = language.name;

    group('the shell in $name', () {
      for (final entry in sizes.entries) {
        testWidgets('fits at ${entry.key}', (tester) async {
          await pumpApp(tester, language, size: entry.value);

          expectNoOverflow(tester, 'the shell in $name at ${entry.key}');
        });
      }

      testWidgets('the menu bar opens all three menus', (tester) async {
        // Doc 09's M3 DoD names the menu bar specifically, because its titles
        // carry the accelerator markers and its items are the longest labels
        // in the app.
        await pumpApp(tester, language, size: sizes['narrow']!);
        final l10n = await AppLocalizations.delegate.load(
          Locale(language.name),
        );

        for (final title in <String>[
          l10n.menuFile,
          l10n.menuView,
          l10n.menuHelp,
        ]) {
          await tester.tap(find.text(title.replaceAll('&', '')));
          await tester.pumpAndSettle();
          expectNoOverflow(tester, '$title in $name');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      });

      testWidgets('the settings screen fits', (tester) async {
        await pumpApp(tester, language, size: sizes['narrow']!);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expectNoOverflow(tester, 'settings in $name');
      });

      testWidgets('the quick switcher fits', (tester) async {
        await pumpApp(tester, language, size: sizes['narrow']!);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expectNoOverflow(tester, 'the quick switcher in $name');
      });

      testWidgets('the search panel fits', (tester) async {
        await pumpApp(tester, language, size: sizes['narrow']!);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expectNoOverflow(tester, 'the search panel in $name');
      });

      testWidgets('the update banner fits', (tester) async {
        // The banner is a single row of translated text beside two controls,
        // above a tab strip — the narrowest thing in the window.
        await pumpApp(tester, language, size: sizes['narrow']!);

        expect(find.byType(UpdateBanner), findsOneWidget);
        expectNoOverflow(tester, 'the update banner in $name');
      });

      testWidgets('the empty state fits, buttons and all', (tester) async {
        final container = await pumpApp(
          tester,
          language,
          size: sizes['narrow']!,
        );

        container.read(openSetProvider.notifier).closeAll();
        await tester.pumpAndSettle();

        // The two Open buttons are why this is a `Wrap`: "Mở thư mục…" beside
        // "Mở tệp…" is wider than the English pair that only just fits.
        expectNoOverflow(tester, 'the empty state in $name');
      });

      testWidgets('the missing-file body fits', (tester) async {
        final container = await pumpApp(
          tester,
          language,
          size: sizes['narrow']!,
        );

        File(at('OTHER.md')).deleteSync();
        container.read(openSetProvider.notifier)
          ..refreshAll()
          ..activate(container.read(openSetProvider).entries.last.identity);
        await tester.pumpAndSettle();

        expectNoOverflow(tester, 'the missing-file body in $name');
      });
    });
  }
}
