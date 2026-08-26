/// `docs/04_MARKDOWN_PIPELINE.md` HTML policy, and
/// `docs/spike-results/S1-renderer-bakeoff.md` Result 3: the renderer deletes
/// block HTML outright, so the content has to be rescued upstream of it.
///
/// The assertions here are about *which* regions get rescued. Catching too
/// little loses content silently; catching too much turns ordinary paragraphs
/// into code blocks.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/markdown_flavor.dart';
import 'package:marklens/core/markdown/raw_block_rewriter.dart';

import '../fixtures/generators.dart';
import 'corpus.dart';

const RawBlockRewriter rewriter = RawBlockRewriter();

String _fixture(String relativePath) => tortureFixtures()
    .firstWhere((f) => f.relativePath == relativePath)
    .readAsString();

/// How many top-level nodes the renderer would drop entirely.
int _droppedNodes(String source) =>
    parseMarkdown(source).whereType<md.Text>().length;

void main() {
  group('the committed HTML fixture', () {
    final source = _fixture('gfm/06_footnotes_and_html.md');

    test('rewrites exactly the four block-HTML regions', () {
      expect(
        rewriter.rewrite(source).rewritten,
        4,
        reason:
            'the fixture holds four regions: the <div> callout, <details> and '
            'its separate </details> (a blank line closes a type-6 block), and '
            'the unterminated <div> at end of file',
      );
    });

    test('leaves inline HTML inside paragraphs alone', () {
      final rewritten = rewriter.rewrite(source).source;

      expect(
        rewritten,
        contains('An HTML comment: <!-- this should not appear'),
        reason:
            'the comment is not at the start of its line, so it is inline '
            'HTML in a paragraph, not a block — fencing it would turn prose '
            'into a code block',
      );
      expect(
        rewritten,
        contains('A self-closing tag: <img src='),
        reason: 'same: the tag does not start the line',
      );
      expect(
        rewritten,
        contains('literal text: <br>, <kbd>Ctrl</kbd>'),
        reason: 'inline HTML is shown as literal text (docs/04), not fenced',
      );
    });

    test('the content the renderer used to delete now survives', () {
      expect(
        _droppedNodes(source),
        4,
        reason:
            'before the rewrite, four regions produce root-level md.Text '
            'nodes, and the builder drops every one of them',
      );
      expect(
        _droppedNodes(rewriter.rewrite(source).source),
        0,
        reason:
            'after the rewrite nothing is left that the renderer would delete '
            '— this is also what restores the blocks[i] -> children[2i] count',
      );
      expect(
        rewriter.rewrite(source).source,
        contains("alert('this must never run')"),
        reason:
            'the script text must be visible as inert source, not executed '
            'and not silently dropped (CLAUDE.md rule 2)',
      );
    });

    test('the unterminated <div> at end of file is closed', () {
      final rewritten = rewriter.rewrite(source).source;
      expect(rewritten, contains('still inside the div at end of file'));
      expect(
        rewritten.trimRight(),
        endsWith('```'),
        reason: 'a region that runs to EOF still needs a closing fence',
      );
    });
  });

  group('MDX components ride the same path', () {
    final source = _fixture('mdx/block_components.mdx');

    test('capitalized block tags are rescued', () {
      expect(
        _droppedNodes(source),
        greaterThan(0),
        reason: 'these are the components the renderer deletes today',
      );
      expect(_droppedNodes(rewriter.rewrite(source).source), 0);

      final rewritten = rewriter.rewrite(source).source;
      for (final tag in <String>['<Callout', '<Tabs>', '<SelfClosing />']) {
        expect(
          rewritten,
          contains(tag),
          reason: '$tag must survive to the reader',
        );
      }
    });

    test('a dotted tag is left alone, because it was never a block', () {
      // `.` is not legal in an HTML tag name, so <Foo.Bar /> is a paragraph,
      // not an HTML block — the renderer already shows it as literal text.
      expect(
        parseMarkdown(source).whereType<md.Text>().map((t) => t.text).join(),
        isNot(contains('Foo.Bar')),
      );
      expect(rewriter.rewrite(source).source, contains('<Foo.Bar prop={1}'));
    });
  });

  group('fencing', () {
    test('escalates past backticks in the content', () {
      const source = '<div>\n```\nnot a real fence\n```\n</div>\n';
      final rewritten = rewriter.rewrite(source).source;

      expect(rewritten, startsWith('````$rawBlockFenceInfo'));
      expect(
        _droppedNodes(rewritten),
        0,
        reason:
            'if the fence were only three backticks the content would close '
            'it early and the rest would leak back out as block HTML',
      );
      expect(rewritten, contains('not a real fence'));
    });

    test('uses the reserved info string so the reader can tell them apart', () {
      final rewritten = rewriter.rewrite('<div>\nx\n</div>\n').source;
      final pre = parseMarkdown(rewritten).first as md.Element;

      expect(pre.tag, 'pre');
      expect(
        pre.attributes['data-metadata'],
        'marklens-raw',
        reason:
            'the marker has to reach the reader, or it cannot tell a rescued '
            'HTML block from a code block the author wrote',
      );
      expect(
        (pre.children!.first as md.Element).attributes['class'],
        'language-html',
        reason: 'the body still highlights as HTML',
      );
    });
  });

  group('documents with no block HTML are returned untouched', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        final result = rewriter.rewrite(source);

        if (result.rewritten == 0) {
          expect(
            result.source,
            same(source),
            reason: 'nothing to do means nothing changed, not even whitespace',
          );
        }
        expect(
          _droppedNodes(result.source),
          0,
          reason: 'no fixture may leave content that the renderer would delete',
        );
      });
    }
  });

  group('line endings and degenerate input', () {
    test('CRLF survives the rewrite', () {
      const source = '# H\r\n\r\n<div>\r\nx\r\n</div>\r\n\r\nAfter.\r\n';
      final rewritten = rewriter.rewrite(source).source;

      expect(rewritten, contains('# H\r\n'));
      expect(rewritten, contains('After.\r\n'));
      expect(
        rewritten.contains('\n\n'),
        isFalse,
        reason:
            'a bare LF would mean the rewriter normalized the terminators '
            'of a CRLF document, and only for documents containing HTML',
      );
    });

    test('an empty document is a no-op', () {
      expect(rewriter.rewrite('').rewritten, 0);
    });

    test('10,000 sibling components stay linear', () {
      expect(
        () => rewriter.rewrite(generateManySiblingComponents()),
        returnsNormally,
      );
    });

    test('deep MDX nesting does not recurse into a stack overflow', () {
      expect(() => rewriter.rewrite(generateDeepMdxNesting()), returnsNormally);
    });
  });
}
