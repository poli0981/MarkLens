/// The reader half of doc 04's MDX placeholder spec: the card a block-level
/// component becomes, and the header chip counting the ESM statements that are
/// no longer in the document.
///
/// The transform itself is covered in `test/core/mdx_sanitizer_test.dart`.
/// What is asserted here is only what a reader can see.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

const MarkdownPipeline pipeline = MarkdownPipeline();

DocModel parseMdx(String source) =>
    pipeline.parse(path: 'test.mdx', bytes: utf8.encode(source), isMdx: true);

Future<void> pump(WidgetTester tester, DocModel doc) async {
  tester.view
    ..physicalSize = const Size(1000, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ReaderView(doc: doc)),
    ),
  );
  await tester.pump();
}

/// Every attribute-summary tooltip on screen, by its message.
List<String> attributeSummaries(WidgetTester tester) => tester
    .widgetList<Tooltip>(find.byType(Tooltip))
    .map((tooltip) => tooltip.message ?? '')
    .where((message) => message.startsWith('Attributes:'))
    .toList();

void main() {
  group('the placeholder card', () {
    testWidgets('is titled with the component, and opens collapsed', (
      tester,
    ) async {
      await pump(
        tester,
        parseMdx(
          '<Callout type="warning" title="Heads up">\nBody.\n'
          '</Callout>\n',
        ),
      );

      expect(find.textContaining('Callout'), findsWidgets);
      expect(
        find.text('Body.'),
        findsNothing,
        reason: 'the box itself is the signal; the source is behind a click',
      );
    });

    testWidgets('expands to the escaped raw source, never rendered', (
      tester,
    ) async {
      await pump(
        tester,
        parseMdx('<Callout type="note">\n**not bold**\n</Callout>\n'),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(
        find.textContaining('**not bold**'),
        findsOneWidget,
        reason: 'render, not run — and not re-render either (rule 2)',
      );
      expect(find.textContaining('<Callout type="note">'), findsOneWidget);
    });

    testWidgets('summarises the attribute names beside the title', (
      tester,
    ) async {
      await pump(tester, parseMdx('<Chart data axis legend />\n'));

      expect(find.text('data axis legend'), findsOneWidget);
      expect(
        find.byTooltip('Attributes: data axis legend'),
        findsOneWidget,
        reason:
            'the summary is identifiers, so it needs a label to read as one',
      );
    });

    testWidgets('a component with no attributes shows no summary', (
      tester,
    ) async {
      await pump(tester, parseMdx('<Divider />\n'));

      // The header still has its expand and copy tooltips; what must be absent
      // is the attribute summary.
      expect(attributeSummaries(tester), isEmpty);
    });

    testWidgets('a bailed-out region is an ordinary, uncollapsible block', (
      tester,
    ) async {
      // Doc 04 transform 5: an unclosed component is fenced as `mdx`, and a
      // code block the reader cannot collapse — because at that point it is
      // just source, with no claim made about what it was.
      await pump(tester, parseMdx('<Callout unclosed>\n\nAfter.\n'));

      expect(find.text('mdx'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });
  });

  group('the hidden-imports chip', () {
    testWidgets('counts what the sanitizer removed', (tester) async {
      await pump(
        tester,
        parseMdx("import A from 'a'\nimport B from 'b'\n\n# Title\n"),
      );

      expect(find.text('MDX · 2 imports hidden'), findsOneWidget);
    });

    testWidgets('is singular for one', (tester) async {
      await pump(tester, parseMdx("import A from 'a'\n\n# Title\n"));

      expect(find.text('MDX · 1 import hidden'), findsOneWidget);
    });

    testWidgets('is absent when nothing was hidden', (tester) async {
      await pump(tester, parseMdx('# Title\n'));

      expect(find.textContaining('imports hidden'), findsNothing);
      expect(find.textContaining('MDX ·'), findsNothing);
    });

    testWidgets('and absent for a .md document, which is never sanitized', (
      tester,
    ) async {
      final doc = pipeline.parse(
        path: 'test.md',
        bytes: utf8.encode("import A from 'a'\n\n# Title\n"),
        isMdx: false,
      );

      await pump(tester, doc);

      expect(find.textContaining('MDX ·'), findsNothing);
      expect(doc.mdxImportsHidden, 0);
    });
  });
}
