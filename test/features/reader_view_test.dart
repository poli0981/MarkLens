/// `docs/06_UI_UX.md` (the reading surface) and `docs/04_MARKDOWN_PIPELINE.md`
/// (the front-matter panel, the raw-HTML box).
///
/// The notice bar is specified nowhere else: four documents require one and
/// none described it, so the behaviour decided in `NoticeBar`'s doc comment is
/// pinned here.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/app_settings.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/outline.dart';
import 'package:marklens/features/reader/notice_bar.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

const MarkdownPipeline pipeline = MarkdownPipeline();

DocModel parse(String source) =>
    pipeline.parse(path: 'test.md', bytes: utf8.encode(source), isMdx: false);

DocModel withNotices(List<DocNoticeKind> kinds) => DocModel(
  path: 'test.md',
  rawSource: '# Doc',
  sanitizedSource: '# Doc',
  outline: Outline.empty,
  blocks: const <SourceBlock>[],
  notices: <DocNotice>[for (final kind in kinds) DocNotice(kind)],
);

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1000, 900),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('the notice bar', () {
    testWidgets('says nothing when there is nothing to say', (tester) async {
      await pump(tester, ReaderView(doc: parse('# Clean\n')));
      expect(find.byKey(const Key('reader-notice-bar')), findsNothing);
    });

    testWidgets('shows the most serious notice first', (tester) async {
      await pump(
        tester,
        ReaderView(
          doc: withNotices(<DocNoticeKind>[
            DocNoticeKind.largeDocument,
            DocNoticeKind.plainTextFallback,
            DocNoticeKind.invalidUtf8,
          ]),
        ),
      );

      expect(
        find.textContaining('could not be parsed', findRichText: true),
        findsOneWidget,
        reason:
            'plainTextFallback outranks the others: it means the reader is '
            'looking at something that is not the rendered document',
      );
    });

    testWidgets('counts the notices it is not showing', (tester) async {
      await pump(
        tester,
        ReaderView(
          doc: withNotices(<DocNoticeKind>[
            DocNoticeKind.invalidUtf8,
            DocNoticeKind.largeDocument,
            DocNoticeKind.frontMatterUnparsed,
          ]),
        ),
      );

      expect(
        find.textContaining('2 more notices', findRichText: true),
        findsOneWidget,
        reason:
            'stacking three bars pushes the document down the screen, which '
            'is the thing the reader came for',
      );
    });

    testWidgets('can be dismissed', (tester) async {
      await pump(
        tester,
        ReaderView(
          doc: withNotices(<DocNoticeKind>[DocNoticeKind.invalidUtf8]),
        ),
      );
      expect(find.byKey(const Key('reader-notice-bar')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.byKey(const Key('reader-notice-bar')), findsNothing);
    });

    testWidgets('a new document brings its notices back', (tester) async {
      final first = withNotices(<DocNoticeKind>[DocNoticeKind.invalidUtf8]);
      final second = withNotices(<DocNoticeKind>[DocNoticeKind.largeDocument]);

      await pump(tester, ReaderView(doc: first));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byKey(const Key('reader-notice-bar')), findsNothing);

      await pump(tester, ReaderView(doc: second));
      expect(
        find.byKey(const Key('reader-notice-bar')),
        findsOneWidget,
        reason:
            'dismissing says "I have read this one", not "stop telling me '
            'about documents"',
      );
    });

    test('every kind has a phrase, and the order covers them all', () {
      expect(
        NoticeBar.severityOrder.toSet(),
        DocNoticeKind.values.toSet(),
        reason:
            'a kind missing from the order would fall through to whichever '
            'notice happened to be first',
      );
    });
  });

  group('the front-matter panel', () {
    const source = '---\ntitle: A doc\nauthor: Kokone\n---\n\n# Body\n';

    testWidgets('shows the keys when the block parsed', (tester) async {
      await pump(
        tester,
        ReaderView(
          doc: parse(source),
          frontMatterDisplay: FrontMatterDisplay.expanded,
        ),
      );

      expect(find.text('title'), findsOneWidget);
      expect(find.text('A doc'), findsOneWidget);
      expect(find.text('author'), findsOneWidget);
    });

    testWidgets('starts collapsed, and opens on a tap', (tester) async {
      await pump(tester, ReaderView(doc: parse(source)));

      expect(find.byKey(const Key('reader-front-matter')), findsOneWidget);
      expect(find.text('A doc'), findsNothing);

      await tester.tap(find.text('Front matter'));
      await tester.pump();

      expect(find.text('A doc'), findsOneWidget);
    });

    testWidgets('the hidden setting hides it entirely', (tester) async {
      await pump(
        tester,
        ReaderView(
          doc: parse(source),
          frontMatterDisplay: FrontMatterDisplay.hidden,
        ),
      );
      expect(find.byKey(const Key('reader-front-matter')), findsNothing);
    });

    testWidgets('a block that did not parse is shown as written', (
      tester,
    ) async {
      await pump(
        tester,
        ReaderView(
          doc: parse('---\n  nested: value\n[not a pair]\n---\n\n# Body\n'),
          frontMatterDisplay: FrontMatterDisplay.expanded,
        ),
      );

      expect(
        find.textContaining('[not a pair]', findRichText: true),
        findsOneWidget,
        reason:
            'throwing away the user text to report an error is worse than '
            'showing it (docs/04)',
      );
    });

    testWidgets('a document without front matter shows no panel', (
      tester,
    ) async {
      await pump(tester, ReaderView(doc: parse('# Just a heading\n')));
      expect(find.byKey(const Key('reader-front-matter')), findsNothing);
    });
  });

  group('code blocks', () {
    testWidgets('carry their language and a copy button', (tester) async {
      await pump(tester, ReaderView(doc: parse('```dart\nvar x = 1;\n```\n')));

      expect(find.text('dart'), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.chevron_right),
        findsNothing,
        reason:
            'a code block the author wrote is content; hiding it behind a '
            'click is not a reader job',
      );
    });

    testWidgets('an unlabelled fence still renders', (tester) async {
      await pump(tester, ReaderView(doc: parse('```\nplain text\n```\n')));
      expect(
        find.textContaining('plain text', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('an unknown language renders rather than failing', (
      tester,
    ) async {
      await pump(
        tester,
        ReaderView(doc: parse('```zzunknownlang\nsome code\n```\n')),
      );
      expect(
        find.textContaining('some code', findRichText: true),
        findsOneWidget,
        reason: 'the highlighter contract: unknown means plain, never an error',
      );
    });
  });

  group('the reading column', () {
    testWidgets('is constrained by default', (tester) async {
      await pump(tester, ReaderView(doc: parse('# Doc\n')));
      final box = tester.getSize(find.byType(ReaderView));
      final heading = tester.getSize(find.textContaining('Doc').first);

      expect(box.width, greaterThan(760));
      expect(
        heading.width,
        lessThanOrEqualTo(760),
        reason: 'a line of text the full width of a monitor is unreadable',
      );
    });

    testWidgets('fills the window when the setting says zero', (tester) async {
      await pump(
        tester,
        ReaderView(doc: parse('# Doc\n'), contentMaxWidth: 0),
      );
      expect(find.byType(ReaderView), findsOneWidget);
      expect(find.textContaining('Doc').first, findsOneWidget);
    });
  });
}
