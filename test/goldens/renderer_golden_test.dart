@Tags(['golden'])
/// The renderer goldens `docs/12_TESTING.md` has described since M0 and could
/// not have until M4, because they need the bundled fonts and there were none.
///
/// These are typography goldens, and the difference from
/// `shell_chrome_golden_test.dart` is not a matter of degree. Those pin
/// geometry and are deliberately font-free; these pin what the document
/// actually *looks like*, which is the charter's first principle — "the
/// document looks right, and looks the same on both OSes".
///
/// **Which is why this file loads the fonts itself.** `flutter test` does not
/// load the families `pubspec.yaml` declares: a widget test renders `Noto
/// Sans`, `JetBrains Mono` and a family name that does not exist to identical
/// widths, because every request resolves to the substituted test font. That is
/// measured, not assumed (doc 12). A renderer golden taken without the
/// `FontLoader` below would be a picture of the test font and would prove
/// nothing at all — while looking exactly like a passing test.
///
/// The loading is scoped to this file rather than done in a
/// `flutter_test_config.dart`, which would apply suite-wide and make the five
/// layout goldens font-dependent for no benefit.
///
/// **The Japanese page is load-bearing beyond looking nice.** The bundled JP
/// face is a JIS X 0208 subset (doc 01), and `tool/fonts/build_fonts.py` unions
/// in every character of this corpus precisely because a missing kanji renders
/// a tofu box that no behavioural test can see. This golden is the only
/// mechanical check that the union held.
///
/// Regenerate in the container, never on Windows — `tool/goldens/README.md`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Every face `pubspec.yaml` declares, grouped by the family it belongs to.
///
/// Listed rather than parsed out of the pubspec: `test/app/fonts_test.dart`
/// already asserts the two agree, and a golden harness that reads its own
/// configuration from a file is one more thing that can quietly change what a
/// reference image means.
const Map<String, List<String>> _faces = <String, List<String>>{
  'Noto Sans': <String>[
    'fonts/NotoSans-Regular.ttf',
    'fonts/NotoSans-Italic.ttf',
    'fonts/NotoSans-Bold.ttf',
    'fonts/NotoSans-BoldItalic.ttf',
  ],
  'Noto Sans JP': <String>[
    'fonts/NotoSansJP-Regular.otf',
    'fonts/NotoSansJP-Bold.otf',
  ],
  'JetBrains Mono': <String>[
    'fonts/JetBrainsMono-Regular.ttf',
    'fonts/JetBrainsMono-Bold.ttf',
  ],
};

/// The reading column doc 06 gives the reader by default, plus enough height to
/// show a page's opening without producing a megabyte of PNG.
const Size _page = Size(760, 720);

Future<void> _loadFonts() async {
  for (final family in _faces.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// Renders [fixture] from the torture corpus at a fixed size.
Future<void> _pumpFixture(
  WidgetTester tester,
  String fixture, {
  Brightness brightness = Brightness.light,
  FrontMatterDisplay frontMatter = FrontMatterDisplay.collapsed,
}) async {
  tester.view
    ..physicalSize = _page
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final bytes = File('test/fixtures/torture/$fixture').readAsBytesSync();
  final doc = const MarkdownPipeline().parse(
    // A literal path, not the real one: a golden that embeds an absolute path
    // differs between the dev machine and the runner.
    path: '/home/kokone/docs/$fixture',
    bytes: bytes,
    isMdx: fixture.endsWith('.mdx'),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReaderView(doc: doc, frontMatterDisplay: frontMatter),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(ReaderView),
    matchesGoldenFile('goldens/renderer_$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  group('the fonts the bundle exists for', () {
    testWidgets('Vietnamese', (tester) async {
      // Stacked diacritics are where a font without precomposed forms falls
      // apart, and where a wrong fallback shows as inconsistent letterforms
      // rather than as missing glyphs.
      await _pumpFixture(tester, 'i18n/vietnamese.md');
      await _expectGolden(tester, 'vietnamese');
    });

    testWidgets('Japanese', (tester) async {
      // Kana, kanji, half-width katakana, full-width forms and CJK punctuation.
      // A kanji outside JIS X 0208 would appear here as a tofu box.
      await _pumpFixture(tester, 'i18n/japanese.md');
      await _expectGolden(tester, 'japanese');
    });

    testWidgets('Japanese, dark', (tester) async {
      await _pumpFixture(
        tester,
        'i18n/japanese.md',
        brightness: Brightness.dark,
      );
      await _expectGolden(tester, 'japanese_dark');
    });

    testWidgets('Vietnamese, with the front matter open', (tester) async {
      // The front-matter panel is the one surface that renders raw YAML in the
      // mono family, so it is where a missing mono fallback would show.
      await _pumpFixture(
        tester,
        'i18n/vietnamese.md',
        frontMatter: FrontMatterDisplay.expanded,
      );
      await _expectGolden(tester, 'vietnamese_front_matter');
    });
  });

  group('the GFM surface', () {
    testWidgets('headings and text', (tester) async {
      await _pumpFixture(tester, 'gfm/01_headings_and_text.md');
      await _expectGolden(tester, 'gfm_headings');
    });

    testWidgets('lists and task lists', (tester) async {
      await _pumpFixture(tester, 'gfm/02_lists_and_tasks.md');
      await _expectGolden(tester, 'gfm_lists');
    });

    testWidgets('fenced code, highlighted', (tester) async {
      // The one page where the mono family and the doc 06 scope colours are
      // both visible. A highlighter regression that keeps tokenising but stops
      // colouring is invisible to every other test.
      await _pumpFixture(tester, 'gfm/03_code_blocks.md');
      await _expectGolden(tester, 'gfm_code');
    });

    testWidgets('tables', (tester) async {
      await _pumpFixture(tester, 'gfm/04_tables.md');
      await _expectGolden(tester, 'gfm_tables');
    });

    testWidgets('footnotes and the raw-HTML box', (tester) async {
      // doc 04's "Raw HTML (not rendered)" placeholder, which the renderer
      // emits nothing for - it is produced upstream in core/markdown/ (doc 01).
      await _pumpFixture(tester, 'gfm/06_footnotes_and_html.md');
      await _expectGolden(tester, 'gfm_html_box');
    });
  });

  group('the placeholders', () {
    testWidgets('MDX block components', (tester) async {
      await _pumpFixture(tester, 'mdx/block_components.mdx');
      await _expectGolden(tester, 'mdx_placeholders');
    });

    testWidgets('deep nesting', (tester) async {
      await _pumpFixture(tester, 'edge/deep_nesting.md');
      await _expectGolden(tester, 'deep_nesting');
    });
  });
}
