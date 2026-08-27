/// `BlockScroller`: reaching a block a `ListView` has never built.
///
/// The thing worth testing here is not that `reveal` returns — it is that the
/// list actually moved and landed on the right block. The S1 harness taught
/// that lesson expensively: its first version reported "PASS (1078 fps)"
/// measured entirely on a list that had scrolled by zero pixels
/// (`docs/spike-results/S1-renderer-bakeoff.md`). Every assertion below is on
/// where the reader ended up, never on the call completing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/reader_scroll.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/reader_view.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

const MarkdownPipeline pipeline = MarkdownPipeline();

/// A document of [blocks] top-level blocks with deliberately uneven heights,
/// so a fixed-extent estimate cannot accidentally be right.
DocModel document(int blocks) {
  final buffer = StringBuffer();
  for (var i = 0; i < blocks; i++) {
    if (i.isEven) {
      buffer.writeln('## Heading $i');
    } else {
      buffer
        ..writeln('Paragraph $i. ${'padding words ' * (i % 7 + 1)}')
        ..writeln();
    }
    buffer.writeln();
  }
  final doc = pipeline.parse(
    path: 'generated.md',
    bytes: utf8.encode(buffer.toString()),
    isMdx: false,
  );
  return doc;
}

void main() {
  late BlockScroller scroller;

  setUp(() => scroller = BlockScroller());
  tearDown(() => scroller.dispose());

  Future<void> pump(
    WidgetTester tester,
    DocModel doc, {
    double restoreScroll = 0,
    Size size = const Size(800, 600),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderView(
            doc: doc,
            scroller: scroller,
            identity: 'generated.md',
            restoreScroll: restoreScroll,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drives the frames a reveal needs while awaiting it.
  ///
  /// The pulse is off by default: it is a 900 ms timer, and a timer still
  /// pending when the body ends fails the test after it — one of the traps
  /// that costs real time here. The pulse has its own test below.
  Future<void> reveal(
    WidgetTester tester,
    int index, {
    bool pulse = false,
  }) async {
    final done = scroller.reveal(index, pulse: pulse);
    await tester.pumpAndSettle();
    await done;
    await tester.pumpAndSettle();
  }

  group('reveal lands on the block it was asked for', () {
    testWidgets('one far below the fold, never built', (tester) async {
      final doc = document(300);
      await pump(tester, doc);

      expect(
        scroller.topBlock.value,
        0,
        reason: 'the document opens at the top',
      );
      final before = scroller.controller.offset;

      await reveal(tester, 250);

      expect(
        scroller.controller.offset,
        greaterThan(before),
        reason: 'the list must actually have moved, not merely returned',
      );
      expect(
        scroller.topBlock.value,
        250,
        reason:
            'a ListView cannot jump to an index it has not built; '
            'converging on it is the whole point of this class',
      );
    });

    testWidgets('and back to the very top', (tester) async {
      await pump(tester, document(300));
      await reveal(tester, 250);
      await reveal(tester, 0);

      expect(scroller.controller.offset, 0);
      expect(scroller.topBlock.value, 0);
    });

    testWidgets('the last block, without overshooting the extent', (
      tester,
    ) async {
      final doc = document(120);
      await pump(tester, doc);
      await reveal(tester, doc.blocks.length - 1);

      expect(
        scroller.controller.offset,
        lessThanOrEqualTo(scroller.controller.position.maxScrollExtent + 0.5),
      );
      expect(scroller.positionPercent.value, 100);
    });

    testWidgets('an index past the end is clamped, not thrown', (tester) async {
      final doc = document(20);
      await pump(tester, doc);
      await reveal(tester, 9999);

      expect(scroller.topBlock.value, lessThan(doc.blocks.length));
    });
  });

  group('the pulse marks where you landed', () {
    testWidgets('and then goes away', (tester) async {
      await pump(tester, document(60));
      await reveal(tester, 30, pulse: true);

      expect(scroller.pulsingBlock.value, 30);

      await tester.pump(BlockScroller.pulseDuration);
      await tester.pumpAndSettle();
      expect(scroller.pulsingBlock.value, -1);
    });
  });

  group('position', () {
    testWidgets('a document shorter than the window reads zero', (
      tester,
    ) async {
      await pump(tester, document(1));
      expect(
        scroller.positionPercent.value,
        0,
        reason: 'nothing to scroll is the top, not a division by zero',
      );
    });

    testWidgets('scrolling reports whole percents', (tester) async {
      await pump(tester, document(200));
      final extent = scroller.controller.position.maxScrollExtent;

      scroller.controller.jumpTo(extent / 2);
      await tester.pumpAndSettle();

      expect(scroller.positionPercent.value, closeTo(50, 1));
    });
  });

  group('a remembered position', () {
    testWidgets('is restored when the document opens', (tester) async {
      await pump(tester, document(200), restoreScroll: 0.5);
      await tester.pumpAndSettle();

      expect(
        scroller.positionPercent.value,
        closeTo(50, 2),
        reason: 'session.json stores a ratio and nothing has ever read it',
      );
    });

    testWidgets('and settling reports it back for the session', (tester) async {
      final recorded = <(String, double)>[];
      scroller.onScrollSettled = (identity, ratio) =>
          recorded.add((identity, ratio));

      await pump(tester, document(200));
      scroller.controller.jumpTo(
        scroller.controller.position.maxScrollExtent / 4,
      );
      await tester.pump();
      expect(
        recorded,
        isEmpty,
        reason: 'a scroll in progress is not a session write (rule 7)',
      );

      await tester.pump(BlockScroller.settleDelay);
      expect(recorded, hasLength(1));
      expect(recorded.single.$1, 'generated.md');
      expect(recorded.single.$2, closeTo(0.25, 0.02));
    });
  });

  group('a document with nothing in it', () {
    testWidgets('reveals nothing and does not throw', (tester) async {
      final doc = pipeline.parse(
        path: 'empty.md',
        bytes: utf8.encode('\n\n'),
        isMdx: false,
      );
      expect(doc.blocks, isEmpty);

      await pump(tester, doc);
      await reveal(tester, 0);

      expect(scroller.positionPercent.value, 0);
    });
  });
}
