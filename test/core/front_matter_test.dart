/// `docs/04_MARKDOWN_PIPELINE.md` stage 2, and CLAUDE.md rule 9: the front
/// matter never reaches the renderer, and no shape of it is fatal.
///
/// The `edge/front_matter_*` fixtures state their own intent in prose; this
/// file turns that prose into assertions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/front_matter.dart';

import 'corpus.dart';

const FrontMatterSplitter splitter = FrontMatterSplitter();

String _fixture(String name) => tortureFixtures()
    .firstWhere((f) => f.relativePath == 'edge/$name')
    .readAsString();

void main() {
  group('the committed fixtures', () {
    test('front_matter_valid: five fields, body free of the block', () {
      final split = splitter.split(_fixture('front_matter_valid.md'));

      expect(split.frontMatter, isNotNull);
      expect(split.frontMatter!.parsed, isTrue);
      expect(split.frontMatter!.fields, <String, String>{
        'title': 'A valid front matter block',
        'author': 'Kokone',
        'date': '2026-08-23',
        'tags': 'markdown, viewer, test',
        'draft': 'false',
      });
      expect(
        split.frontMatter!.raw,
        startsWith('title: A valid front matter block'),
        reason: 'raw keeps the block as written, fences excluded',
      );
      expect(
        split.body,
        isNot(contains('title:')),
        reason:
            'the fixture says: the block above must never reach the '
            'renderer',
      );
      expect(split.body.trimLeft(), startsWith('# Body starts here'));
    });

    test('front_matter_broken: unparsed, raw kept, nothing thrown', () {
      final split = splitter.split(_fixture('front_matter_broken.md'));

      expect(split.frontMatter, isNotNull);
      expect(
        split.frontMatter!.parsed,
        isFalse,
        reason:
            'nested keys, a tab-indented line and a bare bracketed line '
            'are not simple key: value pairs',
      );
      expect(split.frontMatter!.fields, isEmpty);
      expect(
        split.frontMatter!.raw,
        contains('[this is not key: value at all]'),
        reason:
            'throwing away the user text to report an error is worse than '
            'showing it (docs/04)',
      );
      expect(split.body.trimLeft(), startsWith('# Body'));
    });

    test('front_matter_only: parses, and leaves an empty body', () {
      final split = splitter.split(_fixture('front_matter_only.md'));

      expect(split.frontMatter!.fields, <String, String>{
        'title': 'Nothing but front matter',
      });
      expect(
        split.body,
        isEmpty,
        reason:
            'a document that is nothing but front matter has no body — '
            'the empty-document case docs/04 has to define',
      );
    });

    test('front_matter_not_leading: a fence below line one is body', () {
      final split = splitter.split(_fixture('front_matter_not_leading.md'));

      expect(split.frontMatter, isNull);
      expect(split.body, startsWith('# This heading comes first'));
    });

    test('front_matter_dashes_in_body: only the first fence closes it', () {
      final split = splitter.split(_fixture('front_matter_dashes_in_body.md'));

      expect(split.frontMatter!.fields, <String, String>{
        'title': 'Dashes below',
      });
      expect(
        '---'.allMatches(split.body).length,
        2,
        reason:
            'both thematic breaks stay in the body; neither was mistaken '
            'for a second fence',
      );
    });
  });

  group('rules docs/04 left open', () {
    test('an unterminated block is not front matter at all', () {
      const source = '---\ntitle: never closed\n\n# Still a document\n';
      final split = splitter.split(source);

      expect(split.frontMatter, isNull);
      expect(
        split.body,
        source,
        reason:
            'swallowing the whole document into a panel because a fence '
            'was left open is exactly what rule 9 forbids',
      );
    });

    test('a repeated key keeps the last value', () {
      final split = splitter.split('---\na: one\na: two\n---\nbody\n');
      expect(split.frontMatter!.fields, <String, String>{'a': 'two'});
    });

    test('insertion order is the order the panel will show', () {
      final split = splitter.split('---\nz: 1\na: 2\nm: 3\n---\n');
      expect(split.frontMatter!.fields.keys, <String>['z', 'a', 'm']);
    });

    test('an empty value is a value, not a failure', () {
      final split = splitter.split('---\nkey:\n---\n');
      expect(split.frontMatter!.parsed, isTrue);
      expect(split.frontMatter!.fields, <String, String>{'key': ''});
    });

    test('a colon inside the value is fine', () {
      final split = splitter.split('---\nurl: https://example.com/a:b\n---\n');
      expect(split.frontMatter!.fields['url'], 'https://example.com/a:b');
    });

    test('an empty block parses to no fields', () {
      final split = splitter.split('---\n---\nbody\n');
      expect(split.frontMatter!.parsed, isTrue);
      expect(split.frontMatter!.fields, isEmpty);
      expect(split.frontMatter!.raw, isEmpty);
      expect(split.body, 'body\n');
    });

    test('a `...` terminator closes the block too', () {
      final split = splitter.split('---\na: 1\n...\nbody\n');
      expect(split.frontMatter!.fields, <String, String>{'a': '1'});
      expect(split.body, 'body\n');
    });

    test('an indented fence does not open a block', () {
      final split = splitter.split('  ---\na: 1\n---\n');
      expect(split.frontMatter, isNull);
    });
  });

  group('degenerate input never throws', () {
    for (final source in <String>['', '---', '---\n', '\n', '-', '---\n---']) {
      test('${source.replaceAll('\n', r'\n')} is survivable', () {
        expect(() => splitter.split(source), returnsNormally);
      });
    }

    test('CRLF is split the same way as LF', () {
      final split = splitter.split('---\r\ntitle: crlf\r\n---\r\nbody\r\n');
      expect(split.frontMatter!.fields, <String, String>{'title': 'crlf'});
      expect(split.frontMatter!.raw, 'title: crlf');
      expect(split.body, 'body\r\n');
    });
  });
}
