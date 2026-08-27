/// The outline panel (`docs/06_UI_UX.md`, "Outline"): heading tree, indented
/// by level, current section highlighted on scroll, click to jump.
///
/// `Outline` has been built by the pipeline since M1 with nothing reading it.
/// These are the first tests of the reading half.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/app/theme/app_theme.dart';
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/features/outline/outline_panel.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

void main() {
  late Directory config;
  late ProviderContainer container;

  String write(String name, String contents) {
    final path = '${config.path}${Platform.pathSeparator}$name';
    File(path).writeAsStringSync(contents);
    return path;
  }

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_outline_');
    container = ProviderContainer(
      overrides: [configDirectoryProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  /// Opens [source] and pumps the reader beside the outline, the way the shell
  /// arranges them.
  Future<void> pump(WidgetTester tester, String source) async {
    final path = write('doc.md', source);
    container.read(openSetProvider.notifier).openPaths(<String>[path]);

    tester.view
      ..physicalSize = const Size(900, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final doc = ref.watch(activeDocumentProvider).doc;
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: doc == null
                          ? const SizedBox()
                          : ReaderView(
                              doc: doc,
                              scroller: ref.watch(readerScrollProvider),
                              identity: 'doc.md',
                            ),
                    ),
                    const SizedBox(width: 200, child: OutlinePanel()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inOutline(Finder matching) =>
      find.descendant(of: find.byKey(const Key('outline')), matching: matching);

  Color colourOf(WidgetTester tester, String text) =>
      tester.widget<Text>(inOutline(find.text(text))).style!.color!;

  group('the headings appear', () {
    testWidgets('in document order', (tester) async {
      await pump(tester, '# One\n\ntext\n\n## Two\n\n### Three\n');

      expect(inOutline(find.text('One')), findsOneWidget);
      expect(inOutline(find.text('Two')), findsOneWidget);
      expect(inOutline(find.text('Three')), findsOneWidget);

      final ones = tester.getTopLeft(inOutline(find.text('One'))).dy;
      final twos = tester.getTopLeft(inOutline(find.text('Two'))).dy;
      expect(ones, lessThan(twos));
    });

    testWidgets('indented by level', (tester) async {
      await pump(tester, '# One\n\n## Two\n\n### Three\n');

      final one = tester.getTopLeft(inOutline(find.text('One'))).dx;
      final two = tester.getTopLeft(inOutline(find.text('Two'))).dx;
      final three = tester.getTopLeft(inOutline(find.text('Three'))).dx;

      expect(two, greaterThan(one));
      expect(three, greaterThan(two));
    });

    testWidgets('with the indent capped so deep headings stay readable', (
      tester,
    ) async {
      await pump(tester, '#### Four\n\n##### Five\n\n###### Six\n');

      final four = tester.getTopLeft(inOutline(find.text('Four'))).dx;
      final six = tester.getTopLeft(inOutline(find.text('Six'))).dx;
      expect(
        six,
        four,
        reason: 'past level 4 the indent stops; losing the text is worse',
      );
    });
  });

  group('a document with no headings', () {
    testWidgets('collapses to a sentence, not an empty box', (tester) async {
      await pump(tester, 'Just a paragraph, and another.\n\nAnd a third.\n');
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(inOutline(find.text(l10n.outlineEmpty)), findsOneWidget);
      expect(
        inOutline(find.byType(ListView)),
        findsNothing,
        reason: 'doc 06: it collapses gracefully rather than showing nothing',
      );
    });
  });

  group('the current heading follows the reader', () {
    String longDocument() {
      final buffer = StringBuffer();
      for (var section = 0; section < 12; section++) {
        buffer
          ..writeln('## Section $section')
          ..writeln();
        for (var line = 0; line < 6; line++) {
          buffer
            ..writeln('Body $section-$line with a reasonable amount of text.')
            ..writeln();
        }
      }
      return buffer.toString();
    }

    testWidgets('highlighted with the accent, and only one at a time', (
      tester,
    ) async {
      await pump(tester, longDocument());
      const tokens = ReaderTokens.light;

      expect(
        colourOf(tester, 'Section 0'),
        tokens.accent,
        reason: 'the reader opens under the first heading',
      );
      expect(colourOf(tester, 'Section 1'), tokens.fgMuted);
    });

    testWidgets('moving as the document scrolls', (tester) async {
      await pump(tester, longDocument());
      final scroller = container.read(readerScrollProvider);
      const tokens = ReaderTokens.light;

      scroller.controller.jumpTo(
        scroller.controller.position.maxScrollExtent * 0.6,
      );
      await tester.pumpAndSettle();

      expect(
        colourOf(tester, 'Section 0'),
        tokens.fgMuted,
        reason: 'scroll-spy must move off the first heading',
      );
      final highlighted = <String>[
        for (var i = 0; i < 12; i++)
          if (colourOf(tester, 'Section $i') == tokens.accent) 'Section $i',
      ];
      expect(highlighted, hasLength(1));
    });
  });

  group('clicking an entry', () {
    testWidgets('moves the reader to that heading', (tester) async {
      final buffer = StringBuffer();
      for (var section = 0; section < 30; section++) {
        buffer
          ..writeln('## Section $section')
          ..writeln()
          ..writeln('Body text for section $section, long enough to scroll.')
          ..writeln();
      }
      await pump(tester, buffer.toString());

      final scroller = container.read(readerScrollProvider);
      expect(scroller.controller.offset, 0);

      await tester.tap(inOutline(find.text('Section 20')));
      await tester.pumpAndSettle();

      expect(
        scroller.controller.offset,
        greaterThan(0),
        reason: 'the click must move the reader, not merely be accepted',
      );
      expect(
        ReaderTokens.light.accent,
        colourOf(tester, 'Section 20'),
        reason: 'and the entry jumped to becomes the current one',
      );

      // A jump lights the accent pulse on the target block, which is a timer;
      // leaving it pending fails the test after the body has passed.
      await tester.pump(BlockScroller.pulseDuration);
    });
  });
}
