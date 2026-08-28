import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/jsx_scanner.dart';
import 'package:marklens/core/markdown/mdx_sanitizer.dart';
import 'package:marklens/core/models/doc_model.dart';

import 'corpus.dart';

/// `docs/12_TESTING.md`: "every transform rule and every adversarial fixture in
/// `test/fixtures/torture/mdx/` has an expected placeholder-model output.
/// Bail-out cases assert the code-block fallback, never an exception."
void main() {
  const sanitizer = MdxSanitizer();

  String sanitize(String source) => sanitizer.sanitize(source).source;

  String fixture(String name) => tortureFixtures()
      .firstWhere((f) => f.relativePath == 'mdx/$name')
      .readAsString();

  MdxSanitizeResult run(String name) => sanitizer.sanitize(fixture(name));

  List<String> kindsOf(MdxSanitizeResult result) =>
      result.notices.map((notice) => notice.kind.name).toList();

  group('transform 1 — ESM lines', () {
    test('every top-level statement goes, and is counted', () {
      final result = run('esm_imports.mdx');

      expect(result.esmRemoved, 4);
      expect(result.source, isNot(contains('import Callout')));
      expect(result.source, isNot(contains("from '@site/src")));
      expect(result.source, isNot(contains('export const meta')));
      expect(
        result.source,
        isNot(contains('export default function')),
        reason: 'a multi-line ESM statement is still one statement',
      );
      expect(result.source, contains('# ESM lines are removed from the flow'));
      expect(kindsOf(result), isEmpty, reason: 'removing ESM is not a problem');
    });

    test('a multi-line statement is consumed to its closing brace', () {
      const source =
          'export default function L({ x }) {\n'
          '  return 1\n'
          '}\n'
          'Body text.\n';

      final result = sanitizer.sanitize(source);

      expect(result.esmRemoved, 1);
      expect(result.source, 'Body text.\n');
    });

    test('prose that merely starts with the word is left alone', () {
      // The worst failure this class could have. `import` and `export` are
      // ordinary English words at the start of an ordinary English sentence.
      const prose =
          'import the module by hand, then continue.\n'
          'exporting data is out of scope.\n'
          'export was discussed above.\n';

      final result = sanitizer.sanitize(prose);

      expect(result.source, prose);
      expect(result.esmRemoved, 0);
    });

    test('a statement whose braces never close is left alone', () {
      const source = 'export default function L() {\nunclosed forever\n';

      final result = const MdxSanitizer(
        esmStatementLineLimit: 2,
      ).sanitize(source);

      expect(result.source, source, reason: 'leaving text is the safe answer');
      expect(result.esmRemoved, 0);
    });
  });

  group('transform 2 — block-level components become placeholder cards', () {
    test('name and attribute names ride the fence info string', () {
      final result = run('block_components.mdx');

      expect(
        result.source,
        contains(
          '```$mdxPlaceholderLanguage $mdxPlaceholderMetadata '
          'Callout type title',
        ),
      );
      expect(
        result.source,
        contains('$mdxPlaceholderMetadata Foo.Bar prop other flag'),
        reason: 'a dotted tag is a component by doc 04 heuristic',
      );
      expect(result.source, contains('$mdxPlaceholderMetadata SelfClosing'));
      expect(kindsOf(result), isEmpty, reason: 'nothing here is ambiguous');
    });

    test('a nested region is one card, not one per child', () {
      final result = run('block_components.mdx');
      final cards = mdxPlaceholderMetadata.allMatches(result.source).length;

      expect(cards, 5, reason: 'Callout, Foo.Bar, Tabs, SelfClosing, VeryLong');
      expect(
        result.source,
        contains('  <Tab label="First">Content of the first tab.</Tab>'),
        reason: 'the children stay inside the card body, verbatim',
      );
    });

    test('a tag spanning several lines is one card', () {
      final result = run('block_components.mdx');

      expect(
        result.source,
        contains(
          '$mdxPlaceholderMetadata VeryLongAttributes alpha beta gamma '
          'delta epsilon',
        ),
      );
    });

    test('a component with prose after it stays a paragraph', () {
      // Block-level means the region *is* the line. Anything else is a
      // paragraph containing a component, and gets the chip.
      const source = '<Foo /> and then some prose.\n';

      expect(sanitize(source), '`⟨Foo⟩` and then some prose.\n');
    });

    test('the summary is capped rather than running off the line', () {
      final attributes = List<String>.generate(20, (i) => 'a$i').join(' ');

      final info = sanitize('<Wide $attributes />\n').split('\n').first;

      expect(info, contains('$mdxPlaceholderMetadata Wide a0 a1'));
      expect(
        mdxPlaceholderOf(info.split(' ').skip(1).join(' '))!.attributes,
        hasLength(mdxSummaryAttributeLimit),
        reason: 'the body still carries every attribute; the summary does not',
      );
    });
  });

  group('transform 3 — inline components become chips', () {
    test('inside blockquotes, lists and table cells', () {
      final result = run('jsx_in_blockquote.mdx');

      expect(result.source, contains('> `⟨Callout⟩`'));
      expect(result.source, contains('> `⟨/Callout⟩`'));
      expect(result.source, contains('- `⟨InList⟩`'));
      expect(result.source, contains('Text, then `⟨Inline⟩` mid-item.'));
      expect(result.source, contains('| one | `⟨InTable⟩` |'));
    });

    test('a closing chip keeps its slash, so the pair reads as a pair', () {
      expect(sanitize('a <Foo> b </Foo> c\n'), 'a `⟨Foo⟩` b `⟨/Foo⟩` c\n');
    });
  });

  group('transform 4 — braced expressions become literal code spans', () {
    test('in paragraphs, link text and table cells', () {
      final result = run('braces_in_links.mdx');

      expect(result.source, contains('paragraph: `{someValue}` renders'));
      expect(result.source, contains('[a `{braced}` link]'));
      expect(result.source, contains('| `{count}` | literal |'));
    });

    test('never inside a link destination, which it would break', () {
      final result = run('braces_in_links.mdx');

      expect(
        result.source,
        contains('[text](https://example.com/{id}).'),
        reason: 'backticks there would not make it literal, only broken',
      );
    });

    test('a template literal gets a longer delimiter', () {
      final result = run('braces_in_links.mdx');

      expect(result.source, contains(r'``{`a template ${literal}`}``'));
    });

    test('an unbalanced brace is not an expression, and is left alone', () {
      final result = run('braces_in_links.mdx');

      expect(result.source, contains('An unbalanced brace: {unclosed'));
    });

    test('a brace already inside inline code is left alone', () {
      final result = run('braces_in_links.mdx');

      expect(
        result.source,
        contains('A brace inside inline code: `{not an expression}`.'),
        reason: 'double-wrapping would show the backticks',
      );
    });
  });

  group('transform 5 — bail-out', () {
    test('nesting past the limit is one fenced mdx block, not a crash', () {
      final result = run('pathological_nesting.mdx');

      expect(result.source, contains('```$mdxBailOutLanguage\n<L1><L2>'));
      expect(result.source, contains('</L2></L1>'));
      expect(kindsOf(result), <String>['mdxBailOut']);
    });

    test('an unclosed component fences the opening tag and nothing else', () {
      final result = run('unterminated_tag.mdx');

      expect(
        result.source,
        contains(
          '```$mdxBailOutLanguage\n'
          '<Callout type="warning">\n```',
        ),
      );
      expect(
        result.source,
        contains('## A heading that appears to be inside the unclosed'),
        reason: 'guessing where the component ends would eat the document',
      );
      expect(result.source, contains('More text that follows.'));
    });

    test('a tag with no `>` at all bails out on its own line', () {
      final result = run('unterminated_tag.mdx');

      expect(
        result.source,
        contains('```$mdxBailOutLanguage\n<Another attr="value"\n```'),
      );
    });

    test('one bail-out notice, however many regions bailed', () {
      final result = run('unterminated_tag.mdx');

      expect(
        kindsOf(result),
        <String>['mdxBailOut'],
        reason: 'doc 06 counts notices; duplicates would inflate the count',
      );
      expect(result.notices.single.kind, DocNoticeKind.mdxBailOut);
    });
  });

  group('what the scanner must not touch', () {
    test('fenced code, indented code and inline code', () {
      final result = run('fence_with_fake_jsx.mdx');

      expect(result.source, contains('```jsx\n<Callout type="warning">\n'));
      expect(result.source, contains('```\n<Unterminated\n```'));
      expect(result.source, contains('`<Callout />` and `{expression}`'));
      expect(result.source, contains('    <IndentedCodeBlock />'));
      expect(
        result.source,
        contains('$mdxPlaceholderMetadata Callout type'),
        reason: 'the real one, after all the decoys, still transforms',
      );
    });

    test('lowercase dotless tags are HTML and stay for RawBlockRewriter', () {
      final result = run('lowercase_is_html.mdx');

      expect(result.source, contains('<div class="wrapper">'));
      expect(result.source, contains('  <p>block html</p>'));
      expect(
        result.source,
        contains('<span>text</span>, <br>, <kbd>Ctrl</kbd>'),
      );
    });

    test('but a dotted lowercase tag is a component', () {
      final result = run('lowercase_is_html.mdx');

      expect(result.source, contains('$mdxPlaceholderMetadata Div'));
      expect(result.source, contains('$mdxPlaceholderMetadata my.component'));
    });

    test('an autolink is not a tag', () {
      const source = 'See <https://example.com> and <a@b.example>.\n';

      expect(sanitize(source), source);
    });

    test('text with no JSX construct in it comes back byte for byte', () {
      final plain = tortureFixtures()
          .map((f) => (path: f.relativePath, source: f.readAsString()))
          .where((f) => !f.source.contains('<') && !f.source.contains('{'))
          .toList();

      expect(plain, isNotEmpty, reason: 'the filter cannot exclude everything');
      for (final f in plain) {
        final out = sanitizer.sanitize(f.source);
        expect(out.source, f.source, reason: '${f.path} changed');
        expect(out.esmRemoved, 0, reason: f.path);
      }
    });

    test('and a .md document never reaches this class at all', () {
      // The braced expression in `gfm/05_links_and_images.md` is ordinary
      // Markdown text, and would be wrapped in backticks if the sanitizer ran
      // over it. It does not: the pipeline decides by file extension, never by
      // sniffing content (doc 04), which is what keeps this transform confined
      // to files that actually are MDX.
      final markdown = tortureFixtures().firstWhere(
        (f) => f.relativePath == 'gfm/05_links_and_images.md',
      );

      expect(markdown.isMdx, isFalse);
      expect(markdown.readAsString(), contains('[a {braced} link]'));
      expect(
        sanitize(markdown.readAsString()),
        contains('[a `{braced}` link]'),
        reason: 'which is exactly why it must not be run on .md files',
      );
    });

    test('CRLF survives a transform', () {
      const source = '# Title\r\n\r\n<Foo bar="1" />\r\n\r\nAfter {x}.\r\n';

      final out = sanitize(source);

      expect(out, contains('\r\n'));
      expect(out, isNot(contains('\n\n\n')));
      expect(
        out.split('\n').where((l) => l.isNotEmpty),
        everyElement(endsWith('\r')),
      );
    });
  });

  group('rule 9 — nothing here throws, on anything', () {
    for (final f in tortureFixtures()) {
      test('survives ${f.relativePath}', () {
        expect(() => sanitizer.sanitize(f.readAsString()), returnsNormally);
      });
    }

    test('and survives what the corpus does not contain', () {
      final nasty = <String>[
        '<',
        '<A',
        '</',
        '</>',
        '{',
        '}',
        '{{{{{{',
        '`',
        '```',
        '<A {',
        '<A "',
        '<A b={',
        r'<A b="\',
        '<A>' * 5000,
        '{' * 5000,
      ];

      for (final source in nasty) {
        expect(
          () => sanitizer.sanitize(source),
          returnsNormally,
          reason: 'input was ${source.length} chars starting "${source[0]}"',
        );
      }
    });

    test('a document of unclosed tags is linear, not quadratic', () {
      // Every unclosed component costs a search for a close that is not there.
      // Given a budget each, that is quadratic — measured at 117/396/1557 ms
      // for 2,500/5,000/10,000 tags, four times the work for twice the input.
      // The per-region span limit does not help, because it only engages above
      // 64 KB and that document is 60 KB. One budget for the whole document
      // makes it linear: the same figures became 12/7/5 ms.
      //
      // Forty thousand tags is 240 KB, which the old behaviour would have
      // taken minutes over — so the ceiling below has three orders of
      // magnitude of headroom. It catches unboundedness, not a slow runner;
      // doc 12 is explicit that CI runners are too noisy for anything finer.
      // The five-second version of this test failed on a shared runner at
      // 5.22 s, which is how the quadratic was found.
      final source = '<A x>\n' * 40000;

      final stopwatch = Stopwatch()..start();
      final result = const MdxSanitizer().sanitize(source);
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 20)),
        reason: 'quadratic rescanning is a denial of service (rule 9)',
      );
      expect(
        kindsOf(result),
        <String>['mdxBailOut'],
        reason: 'the budget changes how long it takes, never what comes out',
      );
    });

    test('and running out of budget still bails out, never truncates', () {
      // A spent budget gives up *earlier* on finding a close, which is the
      // same answer doc 04 gives an unbalanced tag anyway. The document still
      // comes back whole.
      final source = '<A x>\n' * 5000;

      final result = const MdxSanitizer().sanitize(source);

      expect(
        '```$mdxBailOutLanguage'.allMatches(result.source).length,
        5000,
        reason: 'every one of them is fenced, budget or no budget',
      );
      expect(result.source, contains('<A x>'));
    });
  });

  group('the fence the reader reads back', () {
    test('metadata round-trips to a name and its attributes', () {
      final placeholder = mdxPlaceholderOf(
        '$mdxPlaceholderMetadata Callout type title',
      );

      expect(placeholder?.name, 'Callout');
      expect(placeholder?.attributes, <String>['type', 'title']);
    });

    test('a component with no attributes still round-trips', () {
      final placeholder = mdxPlaceholderOf('$mdxPlaceholderMetadata Foo');

      expect(placeholder?.name, 'Foo');
      expect(placeholder?.attributes, isEmpty);
    });

    test('somebody else’s fence is not ours', () {
      expect(mdxPlaceholderOf(null), isNull);
      expect(mdxPlaceholderOf(''), isNull);
      expect(mdxPlaceholderOf('marklens-raw'), isNull);
      expect(mdxPlaceholderOf(mdxPlaceholderMetadata), isNull);
    });

    test('a card body cannot close its own fence', () {
      // The body carries a fence of its own, so the wrapper has to be longer.
      const source = '<Foo>\n```\ninner\n```\n</Foo>\n';

      final out = sanitize(source);

      expect(out, startsWith('````$mdxPlaceholderLanguage'));
      expect(out.trimRight(), endsWith('````'));
    });
  });

  group('the lexer underneath', () {
    test('a `>` inside an attribute value does not end the tag', () {
      final tag = parseJsxTag('<A title="a > b" c={x > y} />', 0);

      expect(tag?.name, 'A');
      expect(tag?.selfClosing, isTrue);
      expect(tag?.attributes, <String>['title', 'c']);
    });

    test('a tag may wrap lines but not span a blank one', () {
      expect(parseJsxTag('<A\n  b="1"\n>', 0)?.name, 'A');
      expect(parseJsxTag('<A\n\n  b="1">', 0), isNull);
    });

    test('depth is reported, not enforced by recursion', () {
      final region = scanJsxRegion('${'<A>' * 30}x${'</A>' * 30}', 0);

      expect(region?.balanced, isTrue);
      expect(region?.maxDepth, 30);
    });

    test('a stray closing tag is unbalanced, not a region', () {
      final region = scanJsxRegion('<A></B></A>', 0);

      expect(region?.balanced, isFalse);
      expect(region?.end, region?.open.end);
    });

    test('a code span grows past any run of backticks inside it', () {
      expect(jsxCodeSpan('a'), '`a`');
      expect(jsxCodeSpan('a`b'), '``a`b``');
      expect(jsxCodeSpan('`'), '`` ` ``');
      expect(jsxCodeSpan(''), '` `');
    });

    test('braces report unbalanced rather than running to the end', () {
      expect(balancedBraceEnd('{a}', 0), 3);
      expect(balancedBraceEnd('{a{b}', 0), isNull);
      expect(balancedBraceEnd('{"}"}', 0), 5);
      expect(skipBracedExpression('{a{b}', 0), 5);
    });
  });
}
