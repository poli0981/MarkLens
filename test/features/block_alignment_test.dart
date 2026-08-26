/// The invariant the whole block index exists to serve: `DocModel.blocks[i]`
/// is the renderer's `children[2i]`.
///
/// `flutter_markdown_plus` puts a `SizedBox` spacer between every pair of real
/// blocks, so `N` blocks arrive as `2N-1` entries — and filtering the spacers
/// out by type is not safe, because an empty heading is a real block that also
/// renders as a `SizedBox` (`docs/01_TECH_STACK.md`,
/// `docs/spike-results/S1-renderer-bakeoff.md` Result 4). Index arithmetic is
/// the only correct mapping, and nothing in the renderer package protects it.
///
/// This is the test that closes the loop. Everything else in the pipeline
/// checks our own parse against our own expectations; this one checks it
/// against the widgets the reader will actually scroll through.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/markdown/raw_block_rewriter.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/features/reader/rendering/flutter_markdown_plus_renderer.dart';

import '../core/corpus.dart';

const MarkdownPipeline pipeline = MarkdownPipeline();

/// Builds [doc] with the real renderer and reports how many entries its child
/// list held, spacers included.
Future<int> _childCount(WidgetTester tester, DocModel doc) async {
  var count = -1;

  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FlutterMarkdownPlusRenderer(
            onBlockCount: (value) => count = value,
          ).build(context, doc),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(count, isNonNegative, reason: 'the renderer never reported a count');
  return count;
}

/// What `2N-1` means when `N` can be zero.
int _expectedChildren(int blocks) => blocks == 0 ? 0 : 2 * blocks - 1;

void main() {
  group('every fixture lines up with the widgets it produces', () {
    for (final fixture in tortureFixtures()) {
      testWidgets(fixture.relativePath, (tester) async {
        final doc = pipeline.parse(
          path: fixture.relativePath,
          bytes: fixture.readAsBytes(),
          isMdx: fixture.isMdx,
        );

        expect(
          await _childCount(tester, doc),
          _expectedChildren(doc.blocks.length),
          reason:
              'the block index and the renderer disagree about how many '
              'top-level blocks ${fixture.relativePath} has, so every anchor '
              'jump and every search hit in it would scroll to the wrong '
              'place. Check that core and the renderer still parse with the '
              'same configuration (markdown_flavor.dart), and that the '
              'block-HTML rewrite ran.',
        );
      });
    }
  });

  group('the cases that used to break the arithmetic', () {
    testWidgets('block HTML no longer costs a widget', (tester) async {
      // Four HTML regions, each of which the renderer deletes when it is left
      // as a bare text node: without the rewrite this document is four blocks
      // ahead of its own widgets.
      final source = tortureFixtures()
          .firstWhere((f) => f.relativePath == 'gfm/06_footnotes_and_html.md')
          .readAsBytes();
      final doc = pipeline.parse(
        path: 'gfm/06_footnotes_and_html.md',
        bytes: source,
        isMdx: false,
      );

      expect(
        await _childCount(tester, doc),
        _expectedChildren(doc.blocks.length),
      );
    });

    testWidgets('and the gate notices when the rewrite is missing', (
      tester,
    ) async {
      // A gate that has never failed proves nothing. With the pre-pass turned
      // off, the four HTML regions go back to being root-level text nodes that
      // the renderer silently drops, and the counts must diverge by exactly
      // four blocks — which is what this whole file is here to catch.
      const withoutRewrite = MarkdownPipeline(
        rawBlockRewriter: _PassThroughRewriter(),
      );
      final doc = withoutRewrite.parse(
        path: 'gfm/06_footnotes_and_html.md',
        bytes: tortureFixtures()
            .firstWhere(
              (f) => f.relativePath == 'gfm/06_footnotes_and_html.md',
            )
            .readAsBytes(),
        isMdx: false,
      );

      expect(
        await _childCount(tester, doc),
        _expectedChildren(doc.blocks.length - 4),
        reason:
            'without the rewrite the renderer builds four fewer blocks than '
            'the index describes. If this ever matches the un-reduced count, '
            'either the renderer started rendering block HTML or this gate '
            'stopped measuring anything.',
      );
    });

    testWidgets('the rescued HTML actually reaches the screen', (tester) async {
      // The counts can line up while the box renders empty, so this checks the
      // thing a person would check by opening the file: is the text there?
      // It stands in for the manual pass until the reader screen exists — the
      // app shell has no document view yet (M1 step 5).
      final doc = pipeline.parse(
        path: 'callout.md',
        bytes: utf8.encode(
          '# Before\n\n'
          '<div class="callout">\n'
          "  <script>alert('this must never run');</script>\n"
          '</div>\n\n'
          '# After\n',
        ),
        isMdx: false,
      );

      await _childCount(tester, doc);

      expect(
        find.textContaining("alert('this must never run')", findRichText: true),
        findsWidgets,
        reason:
            'the script is shown as inert source. Finding nothing here means '
            'the content is being deleted again — visible to a test, invisible '
            'to a reader.',
      );
      expect(
        find.textContaining('<div class="callout">', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('an empty document produces no children', (tester) async {
      final doc = pipeline.parse(
        path: 'empty.md',
        bytes: const <int>[],
        isMdx: false,
      );

      expect(doc.blocks, isEmpty);
      expect(await _childCount(tester, doc), 0);
    });

    testWidgets('a front-matter-only document produces no children', (
      tester,
    ) async {
      final doc = pipeline.parse(
        path: 'front_matter_only.md',
        bytes: utf8.encode('---\ntitle: Nothing but front matter\n---\n'),
        isMdx: false,
      );

      expect(
        doc.blocks,
        isEmpty,
        reason: 'the body is empty once the front matter is lifted out',
      );
      expect(await _childCount(tester, doc), 0);
    });

    testWidgets('an empty heading is a block, not a spacer', (tester) async {
      // The reason spacers cannot be filtered out by type: this document's
      // second block renders as a SizedBox of its own.
      final doc = pipeline.parse(
        path: 'empty_heading.md',
        bytes: utf8.encode('# Real\n\n#\n\n# Also real\n'),
        isMdx: false,
      );

      expect(doc.blocks.length, 3);
      expect(await _childCount(tester, doc), 5);
    });

    testWidgets('footnote definitions are hoisted into one extra block', (
      tester,
    ) async {
      final doc = pipeline.parse(
        path: 'footnotes.md',
        bytes: utf8.encode(
          'Text.[^1]\n\n[^1]: The note.\n\nMore text.\n',
        ),
        isMdx: false,
      );

      expect(
        doc.blocks.length,
        3,
        reason:
            'two paragraphs plus the section the parser synthesizes at the '
            'end out of the hoisted definition',
      );
      expect(await _childCount(tester, doc), 5);
    });
  });
}

/// A rewriter that does nothing, used to prove the alignment gate has teeth.
class _PassThroughRewriter implements RawBlockRewriter {
  const _PassThroughRewriter();

  @override
  RawBlockRewrite rewrite(String source) => (source: source, rewritten: 0);
}
