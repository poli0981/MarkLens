/// `docs/04_MARKDOWN_PIPELINE.md` ("Heading anchors") and `docs/06_UI_UX.md`
/// (outline panel, scroll-spy).
///
/// The slug list is asserted exactly rather than sampled: duplicate suffixes
/// are assigned in document order, so one wrong or missing heading shifts every
/// anchor after it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/markdown_flavor.dart';
import 'package:marklens/core/markdown/outline_builder.dart';
import 'package:marklens/core/models/outline.dart';

import '../fixtures/generators.dart';
import 'corpus.dart';

const OutlineBuilder builder = OutlineBuilder();

String _fixture(String relativePath) => tortureFixtures()
    .firstWhere((f) => f.relativePath == relativePath)
    .readAsString();

void main() {
  group('heading_slug_collisions.md', () {
    final outline = builder.build(
      parseMarkdown(_fixture('edge/heading_slug_collisions.md')),
    );

    test('every heading is present, in document order', () {
      expect(outline.entries.length, 16);
      expect(outline.entries.every((e) => e.level == 1), isTrue);
    });

    test('the slugs are exactly these', () {
      expect(outline.entries.map((e) => e.slug).toList(), <String>[
        'setup',
        'setup-1',
        // `Setup 1` slugifies to `setup-1`, which the previous duplicate
        // already claimed, so it takes the next free suffix. A naive
        // "append -N" scheme would emit a duplicate anchor here.
        'setup-1-1',
        'setup-2',
        'setup-3',
        'setup-4',
        'setup-5',
        'setup-6',
        'cài-đặt',
        'cài-đặt-1',
        '設定',
        '設定-1',
        // Two empty headings: an empty slug is still a slug, and the second
        // one still has to be unique.
        '',
        '-1',
        '12',
        // `1.2` strips its dot to `12`, colliding with the heading above.
        '12-1',
      ]);
    });

    test('every slug is unique', () {
      final slugs = outline.entries.map((e) => e.slug).toList();
      expect(
        slugs.toSet().length,
        slugs.length,
        reason: 'two headings sharing an anchor make one of them unreachable',
      );
    });

    test('each heading points at its own block', () {
      expect(
        outline.entries.map((e) => e.blockIndex).toList(),
        List<int>.generate(16, (i) => i),
        reason: 'these headings are all top-level blocks of their own',
      );
    });
  });

  group('documents without headings', () {
    test('no_headings.md collapses to nothing rather than erroring', () {
      final outline = builder.build(
        parseMarkdown(_fixture('edge/no_headings.md')),
      );
      expect(outline.isEmpty, isTrue);
      expect(outline.entries, isEmpty);
    });

    test('an empty document has an empty outline', () {
      expect(builder.build(parseMarkdown('')).isEmpty, isTrue);
    });
  });

  group('levels and text', () {
    test('atx and setext headings both land, with the right levels', () {
      final outline = builder.build(
        parseMarkdown(_fixture('gfm/01_headings_and_text.md')),
      );
      final firstEight = outline.entries.take(8).toList();

      expect(
        firstEight.map((e) => e.level).toList(),
        <int>[1, 2, 3, 4, 5, 6, 1, 2],
        reason:
            'six atx levels, then setext level 1 and level 2 — setext headings '
            'are h1/h2 and must not be missed',
      );
      expect(firstEight[6].text, 'Setext level 1');
      expect(firstEight[7].text, 'Setext level 2');
    });

    test('inline formatting is stripped from the text', () {
      final outline = builder.build(
        parseMarkdown('# A *heading* with `code` and **bold**\n'),
      );
      expect(outline.entries.single.text, 'A heading with code and bold');
      expect(outline.entries.single.slug, 'a-heading-with-code-and-bold');
    });
  });

  group('nested headings', () {
    test('a heading inside a block quote carries its block index', () {
      const source = '# Top\n\n> ## Quoted\n\n# After\n';
      final outline = builder.build(parseMarkdown(source));

      expect(outline.entries.map((e) => e.text).toList(), <String>[
        'Top',
        'Quoted',
        'After',
      ]);
      expect(
        outline.entries[1].blockIndex,
        1,
        reason:
            'the quoted heading has no block of its own, so it points at the '
            'block quote that renders it',
      );
      expect(outline.entries[2].blockIndex, 2);
    });

    test('a nested duplicate still consumes its suffix', () {
      const source = '# Setup\n\n> # Setup\n\n# Setup\n';
      final outline = builder.build(parseMarkdown(source));

      expect(
        outline.entries.map((e) => e.slug).toList(),
        <String>['setup', 'setup-1', 'setup-2'],
        reason:
            'skipping the nested heading would give the third one setup-1, '
            'which is the anchor GitHub assigns to the nested one — every '
            'link to it would land on the wrong heading',
      );
    });

    test('a heading inside a list item is found', () {
      final outline = builder.build(parseMarkdown('- item\n\n  # Inside\n'));
      expect(outline.entries.map((e) => e.text), contains('Inside'));
    });
  });

  group('adversarial input', () {
    test('deep nesting does not overflow the stack', () {
      expect(
        () => builder.build(parseMarkdown(_fixture('edge/deep_nesting.md'))),
        returnsNormally,
      );
    });

    test('50 levels of MDX nesting', () {
      expect(
        () => builder.build(parseMarkdown(generateDeepMdxNesting())),
        returnsNormally,
      );
    });

    test('every fixture builds an outline without throwing', () {
      for (final fixture in tortureFixtures()) {
        expect(
          () => builder.build(parseMarkdown(fixture.readAsString())),
          returnsNormally,
          reason: fixture.relativePath,
        );
      }
    });
  });

  group('the two lookups the panel and anchor links need', () {
    const outline = Outline(<OutlineEntry>[
      OutlineEntry(level: 1, text: 'Top', slug: 'top', blockIndex: 2),
      OutlineEntry(level: 2, text: 'Middle', slug: 'middle', blockIndex: 5),
      OutlineEntry(level: 2, text: 'End', slug: 'end', blockIndex: 9),
    ]);

    test('headingAt is null above the first heading', () {
      expect(
        outline.headingAt(0),
        isNull,
        reason: 'a document may well open with a paragraph',
      );
      expect(outline.headingAt(1), isNull);
    });

    test('headingAt returns the heading a block sits under', () {
      expect(outline.headingAt(2)?.slug, 'top');
      expect(outline.headingAt(4)?.slug, 'top');
      expect(outline.headingAt(5)?.slug, 'middle');
      expect(outline.headingAt(8)?.slug, 'middle');
      expect(outline.headingAt(9)?.slug, 'end');
      expect(
        outline.headingAt(9999)?.slug,
        'end',
        reason: 'past the last heading the reader is still under it',
      );
    });

    test('the innermost heading wins when several share a block', () {
      // Headings nested in a list or a block quote carry the enclosing
      // top-level block's index (doc 04), so this really happens.
      const nested = Outline(<OutlineEntry>[
        OutlineEntry(level: 1, text: 'Outer', slug: 'outer', blockIndex: 3),
        OutlineEntry(level: 2, text: 'Inner', slug: 'inner', blockIndex: 3),
      ]);
      expect(nested.headingAt(3)?.slug, 'inner');
    });

    test('an empty outline answers null rather than throwing', () {
      expect(Outline.empty.headingAt(0), isNull);
      expect(Outline.empty.bySlug('anything'), isNull);
    });

    test('bySlug finds an anchor, and misses cleanly', () {
      expect(outline.bySlug('middle')?.blockIndex, 5);
      expect(outline.bySlug('not-a-heading'), isNull);
    });
  });
}
