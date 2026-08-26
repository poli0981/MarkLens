/// `docs/04_MARKDOWN_PIPELINE.md` ("Why the block index exists") and
/// `docs/08_SEARCH.md`: every search hit maps to a block, and every block maps
/// to a widget the renderer built.
///
/// The invariants here are what make that possible — a partition of the source
/// with non-decreasing offsets, one block per top-level node, in render order.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/block_index.dart';

import '../fixtures/generators.dart';
import 'corpus.dart';

const BlockIndexer indexer = BlockIndexer();

String _fixture(String relativePath) => tortureFixtures()
    .firstWhere((f) => f.relativePath == relativePath)
    .readAsString();

void main() {
  group('one block per top-level node, in render order', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final result = indexer.index(fixture.readAsString());

        expect(result.degraded, isFalse);
        expect(
          result.blocks.length,
          result.nodes.length,
          reason:
              'the block list and the node list must stay one to one, or '
              'blocks[i] stops meaning children[2i]',
        );
        for (var i = 0; i < result.blocks.length; i++) {
          expect(result.blocks[i].index, i);
        }
      });
    }
  });

  group('the blocks partition the source', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        final blocks = indexer.index(source).blocks;
        if (blocks.isEmpty) {
          return;
        }

        expect(
          blocks.first.startOffset,
          0,
          reason: 'anything above the first block still belongs to it',
        );
        expect(
          blocks.map((b) => b.startOffset),
          _isNonDecreasing,
          reason:
              'offsets must be non-decreasing so a search hit can be located '
              'by binary search rather than a scan',
        );

        for (var i = 0; i < blocks.length - 1; i++) {
          expect(
            blocks[i].endOffset,
            blocks[i + 1].startOffset,
            reason:
                'block $i ends at ${blocks[i].endOffset} but block ${i + 1} '
                'starts at ${blocks[i + 1].startOffset} — the gap holds source '
                'that nothing can scroll to',
          );
        }
        expect(
          blocks.last.endOffset,
          source.length,
          reason: 'the last block runs to the end of the file',
        );

        for (final block in blocks) {
          expect(block.endOffset, greaterThanOrEqualTo(block.startOffset));
          expect(block.endLine, greaterThanOrEqualTo(block.startLine));
        }
      });
    }
  });

  group('documents with no blocks at all', () {
    test('an empty file', () {
      expect(indexer.index('').blocks, isEmpty);
    });

    test('only blank lines', () {
      expect(indexer.index('\n\n\n').blocks, isEmpty);
    });

    test('only a link reference definition', () {
      // A non-empty source with zero blocks: LinkReferenceDefinitionSyntax
      // produces no node, so the renderer builds no children either. This is
      // why "at least one block" is not a safe invariant.
      expect(indexer.index('[ref]: https://example.com\n').blocks, isEmpty);
    });
  });

  group('setext headings start at the text, not the underline', () {
    test('a bare setext heading', () {
      const source = 'The heading text\n================\n\nA paragraph.\n';
      final result = indexer.index(source);

      expect(result.nodes.length, 2);
      expect(
        result.blocks.first.startLine,
        0,
        reason:
            'SetextHeaderSyntax runs when the parser is on the underline and '
            'reaches back through linesToConsume for the text above. Recording '
            'the current line would put the heading on line 1, and every '
            'anchor jump to it would land a line short.',
      );
      expect(
        source.substring(
          result.blocks.first.startOffset,
          result.blocks.first.endOffset,
        ),
        contains('The heading text'),
        reason: 'the block must actually contain its own heading text',
      );
    });

    test('a setext heading after a paragraph', () {
      const source = 'Intro paragraph.\n\nHeading\n-------\n\nBody.\n';
      final result = indexer.index(source);

      expect(result.nodes.length, 3);
      expect(result.blocks[1].startLine, 2);
      expect(
        source.substring(
          result.blocks[1].startOffset,
          result.blocks[1].endOffset,
        ),
        startsWith('Heading\n-------'),
      );
    });

    test('the committed fixture locates both setext headings', () {
      final source = _fixture('gfm/01_headings_and_text.md');
      final result = indexer.index(source);

      // Lines 13-14 and 16-17 of the fixture (1-based) are the two setext
      // headings. Their blocks must start on the text line, not the underline.
      for (final startLine in <int>[12, 15]) {
        final block = result.blocks.firstWhere(
          (b) => b.startLine == startLine,
          orElse: () => throw StateError(
            'no block starts on line $startLine; starts are '
            '${result.blocks.map((b) => b.startLine).toList()}',
          ),
        );
        expect(
          source.substring(block.startOffset, block.endOffset),
          startsWith('Setext level'),
          reason:
              'the block starting at line $startLine should open with the '
              'setext heading text',
        );
      }
    });
  });

  group('the synthesized footnote section', () {
    test('spans nothing, and the definitions stay with the block above', () {
      final source = _fixture('gfm/06_footnotes_and_html.md');
      final result = indexer.index(source);
      final last = result.blocks.last;

      expect(
        last.startOffset,
        source.length,
        reason:
            'the footnote section is built after parsing, out of definitions '
            'lifted from elsewhere in the file, so it has no source position '
            'of its own',
      );
      expect(last.endOffset, source.length);
      expect(
        last.contains(source.length - 1),
        isFalse,
        reason: 'no offset may resolve to a block that spans nothing',
      );
    });
  });

  group('adversarial input never throws', () {
    test('deeply nested lists and block quotes', () {
      expect(
        () => indexer.index(_fixture('edge/deep_nesting.md')),
        returnsNormally,
      );
    });

    test('50 levels of MDX nesting', () {
      expect(() => indexer.index(generateDeepMdxNesting()), returnsNormally);
    });

    test('10,000 sibling components', () {
      expect(
        () => indexer.index(generateManySiblingComponents()),
        returnsNormally,
      );
    });

    test('a 1 MB document', () {
      final result = indexer.index(generateLargeDocument());
      expect(result.degraded, isFalse);
      expect(result.blocks, isNotEmpty);
    });
  });
}

final Matcher _isNonDecreasing = predicate<Iterable<int>>((values) {
  var previous = -1;
  for (final value in values) {
    if (value < previous) {
      return false;
    }
    previous = value;
  }
  return true;
}, 'is non-decreasing');
