import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/word_count.dart';

void main() {
  group('countWords — spaced scripts', () {
    test('counts runs between spaces', () {
      expect(countWords('one two three'), 3);
    });

    test('collapses runs of whitespace', () {
      expect(
        countWords('one   two\t\tthree\n\nfour'),
        4,
        reason: 'consecutive separators are one boundary, not several words',
      );
    });

    test('an empty document has no words', () {
      expect(countWords(''), 0);
      expect(countWords('\n\n   \n'), 0);
    });

    test('punctuation alone is not a word', () {
      expect(
        countWords('| --- | --- |'),
        0,
        reason: 'a table rule is layout; counting it would inflate every table',
      );
      expect(countWords('***'), 0, reason: 'a thematic break is not prose');
      expect(
        countWords('- item'),
        1,
        reason: 'the bullet is punctuation, "item" is the word',
      );
    });

    test('markdown emphasis does not split a word', () {
      expect(countWords('**bold** and _italic_'), 3);
    });

    test('counts Vietnamese diacritics as one word each', () {
      expect(
        countWords('Tiếng Việt rất đẹp'),
        4,
        reason: 'combining marks belong to the run they sit in',
      );
    });
  });

  group('countWords — Japanese', () {
    test('counts each ideograph and kana as a word', () {
      // Five characters, no spaces anywhere.
      expect(
        countWords('日本語の文'),
        5,
        reason: 'whitespace splitting would report this whole line as 1 word',
      );
    });

    test('CJK punctuation separates rather than counting', () {
      // Ten characters, of which 、 and 。 are punctuation.
      expect(
        countWords('これは、テストです。'),
        8,
        reason: 'the ideographic comma and full stop are boundaries',
      );
    });

    test('mixed Japanese and Latin counts both', () {
      expect(
        countWords('MarkLens は速い'),
        4,
        reason: 'one Latin run plus three kana/ideograph characters',
      );
    });

    test('a CJK character ends a Latin run without a space', () {
      expect(countWords('MarkLensは'), 2);
    });
  });

  group('countWords — fenced code is excluded', () {
    test('skips a backtick fence and its fence lines', () {
      const source = '''
before

```dart
final answer = one two three;
```

after
''';
      expect(
        countWords(source),
        2,
        reason: 'only "before" and "after" are prose',
      );
    });

    test('skips a tilde fence', () {
      const source = '~~~\nhidden words here\n~~~\nvisible\n';
      expect(countWords(source), 1);
    });

    test('a tilde line does not close a backtick fence', () {
      const source = '```\n~~~\nstill inside\n```\nout\n';
      expect(
        countWords(source),
        1,
        reason: 'a fence closes only on its own character',
      );
    });

    test('a longer closing fence closes a shorter opening one', () {
      const source = '```\ninside\n`````\nout\n';
      expect(countWords(source), 1);
    });

    test('a shorter run does not close a longer fence', () {
      const source = '`````\ninside\n```\nstill inside\n`````\nout\n';
      expect(countWords(source), 1);
    });

    test('an unterminated fence swallows the rest of the document', () {
      const source = 'before\n\n```\nnever closed\n';
      expect(
        countWords(source),
        1,
        reason: 'CommonMark runs an unterminated fence to end of file',
      );
    });

    test('the rescued raw-HTML block is excluded with every other fence', () {
      const source =
          '```html marklens-raw\n<div>hidden markup</div>\n```\nreal\n';
      expect(
        countWords(source),
        1,
        reason: 'RawBlockRewriter emits a fence, so it costs nothing extra',
      );
    });

    test('four spaces of indentation is an indented block, not a fence', () {
      const source = '    ```\nnot a fence so this counts\n';
      expect(countWords(source), greaterThan(1));
    });

    test('three spaces of indentation still opens a fence', () {
      const source = '   ```\nhidden\n   ```\nout\n';
      expect(countWords(source), 1);
    });
  });

  group('countWords — inline code and the rest of the document', () {
    test('inline code counts, because a reader reads it', () {
      expect(
        countWords('use `flutter test` here'),
        4,
        reason: 'only fenced blocks are skipped, per docs/06',
      );
    });

    test('a heading counts its text and not its hashes', () {
      expect(countWords('## Getting started'), 2);
    });
  });
}
