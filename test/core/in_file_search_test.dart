/// Literal find-in-file over `sanitizedSource` (`docs/08_SEARCH.md`).
///
/// Two of these guard traps rather than features: a hit in the block *before*
/// the synthesized footnote section, which has an empty range at the end of
/// the source (doc 04), and the length-preserving-fold precondition the whole
/// offset arithmetic rests on.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/search/in_file_search.dart';

const MarkdownPipeline pipeline = MarkdownPipeline();

DocModel parse(String source) =>
    pipeline.parse(path: 'doc.md', bytes: utf8.encode(source), isMdx: false);

List<FindHit> findIn(
  DocModel doc,
  String query, {
  bool caseSensitive = false,
}) => findInSource(
  source: doc.sanitizedSource,
  blocks: doc.blocks,
  query: query,
  caseSensitive: caseSensitive,
);

void main() {
  group('counting matches', () {
    test('finds every occurrence', () {
      final doc = parse('alpha beta\n\nalpha gamma\n\nalpha\n');
      expect(findIn(doc, 'alpha'), hasLength(3));
    });

    test('matches do not overlap', () {
      final doc = parse('aaaa\n');
      expect(
        findIn(doc, 'aa'),
        hasLength(2),
        reason: '"aa" in "aaaa" is two matches, not three',
      );
    });

    test('an empty query matches nothing', () {
      expect(findIn(parse('anything\n'), ''), isEmpty);
    });

    test('a query longer than the document matches nothing', () {
      expect(findIn(parse('hi\n'), 'a much longer query'), isEmpty);
    });

    test('it is literal, not a pattern', () {
      final doc = parse('a.c and abc and a*c\n');
      expect(
        findIn(doc, 'a.c'),
        hasLength(1),
        reason: 'doc 08 keeps regex as a v1.x candidate, deliberately',
      );
      expect(findIn(doc, 'a*c'), hasLength(1));
    });
  });

  group('case', () {
    test('insensitive by default', () {
      final doc = parse('Alpha alpha ALPHA\n');
      expect(findIn(doc, 'alpha'), hasLength(3));
    });

    test('sensitive when asked', () {
      final doc = parse('Alpha alpha ALPHA\n');
      expect(findIn(doc, 'alpha', caseSensitive: true), hasLength(1));
    });

    test('folding never moves an offset off its match', () {
      // Dart folds with simple case mapping, so `İ` becomes a single `i` and
      // the offsets stay aligned — which is what lets an insensitive search
      // match it at all. The invariant, not the character, is the point:
      // every offset must still point at something the length of the query.
      final doc = parse('İstanbul and istanbul and ẞ and ß\n');

      for (final query in <String>['istanbul', 'ß']) {
        final hits = findIn(doc, query);
        expect(hits, isNotEmpty, reason: 'nothing matched "$query"');
        for (final hit in hits) {
          expect(
            hit.length,
            query.length,
            reason:
                'a hit that is not the length of the query would leave '
                'every later offset pointing at the wrong characters',
          );
          expect(
            hit.offset + hit.length,
            lessThanOrEqualTo(doc.sanitizedSource.length),
          );
        }
      }
    });
  });

  group('scripts', () {
    test('Vietnamese diacritics', () {
      final doc = parse('Tiếng Việt và tiếng Anh\n');
      expect(findIn(doc, 'tiếng'), hasLength(2));
      expect(findIn(doc, 'tiếng', caseSensitive: true), hasLength(1));
    });

    test('Japanese', () {
      final doc = parse('日本語の文書と日本語の見出し\n');
      expect(findIn(doc, '日本語'), hasLength(2));
    });
  });

  group('hits resolve to the block that renders them', () {
    test('one block per paragraph', () {
      final doc = parse('first\n\nsecond\n\nthird target\n');
      final hit = findIn(doc, 'target').single;

      expect(hit.blockIndex, doc.blocks.length - 1);
      expect(doc.blocks[hit.blockIndex].contains(hit.offset), isTrue);
    });

    test('a match at the very first offset', () {
      final doc = parse('target at the start\n');
      final hit = findIn(doc, 'target').single;
      expect(hit.offset, 0);
      expect(hit.blockIndex, 0);
    });

    test('every hit lands inside the block it names', () {
      final doc = parse(
        '# Heading\n\npara one\n\n- list item\n\n> quoted\n\n'
        '```dart\nfinal code = 1;\n```\n\n| a | b |\n|---|---|\n| c | d |\n',
      );
      for (final hit in findIn(doc, 'a')) {
        expect(hit.blockIndex, isNonNegative);
        expect(
          doc.blocks[hit.blockIndex].contains(hit.offset),
          isTrue,
          reason: 'offset ${hit.offset} was mapped to block ${hit.blockIndex}',
        );
      }
    });

    test('a hit in the last real block of a document with footnotes', () {
      final doc = parse(
        'Body with a target[^1].\n\nAnother paragraph.\n\n'
        '[^1]: The note itself.\n',
      );
      for (final hit in findIn(doc, 'target')) {
        expect(
          doc.blocks[hit.blockIndex].contains(hit.offset),
          isTrue,
          reason:
              'the synthesized footnote section has an empty range at the end '
              'of the source, so a naive search lands on a block that contains '
              'nothing at all (doc 04)',
        );
      }
    });

    test('a document with no blocks yields no hits', () {
      final doc = parse('\n\n   \n');
      expect(doc.blocks, isEmpty);
      expect(findIn(doc, 'anything'), isEmpty);
    });
  });

  group('blockIndexOf', () {
    test('is -1 when there are no blocks', () {
      expect(blockIndexOf(const <SourceBlock>[], 0), -1);
    });

    test('finds the block for every offset in the source', () {
      final doc = parse('# One\n\nTwo\n\n- three\n\n> four\n\nfive\n');
      for (var offset = 0; offset < doc.sanitizedSource.length; offset++) {
        final index = blockIndexOf(doc.blocks, offset);
        expect(
          index,
          isNonNegative,
          reason:
              'doc 04: the blocks partition the source, so every offset '
              'lands in exactly one of them — offset $offset did not',
        );
        expect(doc.blocks[index].contains(offset), isTrue);
      }
    });
  });
}
