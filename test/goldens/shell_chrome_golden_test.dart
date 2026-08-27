@Tags(['golden'])
/// The first goldens in the repo, and deliberately the narrowest useful ones:
/// the two chrome surfaces the first visual pass found broken
/// (`docs/15_SPIKES_ROADMAP.md`).
///
/// These are **layout** goldens, not typography goldens. `flutter_test`
/// substitutes its own fixed-width test font, so what they pin is geometry and
/// composition — where the menu bar starts, how wide it runs, which fields the
/// status bar shows and in what order. The font-dependent renderer goldens
/// doc 12 describes need the bundled fonts, which are still not in the tree.
///
/// Every fixture here is a literal. Nothing reads a temp directory, a real
/// file or a clock, because a golden that embeds `Directory.systemTemp` is a
/// golden that differs between the maintainer's machine and the CI runner.
///
/// Regenerate on Ubuntu, never on Windows — four of these five differ between
/// the two platforms. `tool/goldens/README.md` has the container and the
/// commands.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/menu/app_menu_bar.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/opened_file.dart';
import 'package:marklens/features/status/status_bar.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// A path that reads the same on both operating systems.
const String samplePath = '/home/kokone/projects/marklens/docs/06_UI_UX.md';

/// Pins the settings, so no golden reads `settings.json` — the menu bar takes
/// its theme from there, and the real controller would want a config directory.
class _FixedSettings extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings();
}

/// Pins the active document, so no golden depends on the filesystem.
class _FixedDocument extends ActiveDocumentController {
  _FixedDocument(this._value);

  final ActiveDocument _value;

  @override
  ActiveDocument build() => _value;
}

ActiveDocument documentOf(String source) {
  final doc = const MarkdownPipeline().parse(
    path: samplePath,
    bytes: source.codeUnits,
    isMdx: false,
  );
  return ActiveDocument(
    file: OpenedFile(
      path: samplePath,
      identity: samplePath,
      modified: DateTime.utc(2026, 8, 27),
      size: source.length,
    ),
    doc: doc,
  );
}

Future<void> pumpChrome(
  WidgetTester tester,
  Widget child, {
  required Size size,
  ActiveDocument? document,
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FixedSettings.new),
        if (document != null)
          activeDocumentProvider.overrideWith(() => _FixedDocument(document)),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the status bar', () {
    testWidgets('shows path, position, word count', (tester) async {
      await pumpChrome(
        tester,
        const Align(alignment: Alignment.topCenter, child: StatusBar()),
        size: const Size(900, 60),
        document: documentOf('# Reading surface\n\nA short paragraph here.\n'),
      );

      await expectLater(
        find.byKey(const Key('status-bar')),
        matchesGoldenFile('goldens/status_bar_light.png'),
      );
    });

    testWidgets('adds a notice count when the document raised one', (
      tester,
    ) async {
      await pumpChrome(
        tester,
        const Align(alignment: Alignment.topCenter, child: StatusBar()),
        size: const Size(900, 60),
        document: documentOf('---\nnot a pair\n---\n\n# Heading\n'),
      );

      await expectLater(
        find.byKey(const Key('status-bar')),
        matchesGoldenFile('goldens/status_bar_notices.png'),
      );
    });

    testWidgets('says so when nothing is open', (tester) async {
      await pumpChrome(
        tester,
        const Align(alignment: Alignment.topCenter, child: StatusBar()),
        size: const Size(900, 60),
      );

      await expectLater(
        find.byKey(const Key('status-bar')),
        matchesGoldenFile('goldens/status_bar_empty.png'),
      );
    });

    testWidgets('and reads the same in the dark theme', (tester) async {
      await pumpChrome(
        tester,
        const Align(alignment: Alignment.topCenter, child: StatusBar()),
        size: const Size(900, 60),
        document: documentOf('# Reading surface\n\nA short paragraph here.\n'),
        brightness: Brightness.dark,
      );

      await expectLater(
        find.byKey(const Key('status-bar')),
        matchesGoldenFile('goldens/status_bar_dark.png'),
      );
    });
  });

  group('the menu bar', () {
    testWidgets('spans the window from its left edge', (tester) async {
      await pumpChrome(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[AppMenuBar(fileMenuController: MenuController())],
        ),
        size: const Size(900, 80),
      );

      await expectLater(
        find.byType(MenuBar),
        matchesGoldenFile('goldens/menu_bar_light.png'),
      );
    });
  });
}
