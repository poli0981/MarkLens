/// `SourceLines` must cut a source into exactly the lines `LineSplitter` does,
/// because that is what `markdown` and `flutter_markdown_plus` both use. If the
/// two ever disagree, every offset the block index reports is off by however
/// many terminators were counted differently — so the agreement is asserted
/// here rather than assumed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/markdown_flavor.dart';
import 'package:marklens/core/markdown/source_lines.dart';

import 'corpus.dart';

void main() {
  group('SourceLines agrees with LineSplitter', () {
    const cases = <String, String>{
      'empty': '',
      'no terminator': 'one',
      'trailing lf': 'one\n',
      'blank line between': 'one\n\ntwo\n',
      'crlf': 'one\r\ntwo\r\n',
      'mixed': 'one\ntwo\r\nthree\rfour',
      'lone cr': 'one\rtwo',
      'only terminators': '\n\n\n',
      'trailing blank line': 'one\n\n',
    };

    cases.forEach((name, source) {
      test(name, () {
        expect(SourceLines.of(source).contents, splitMarkdownLines(source));
      });
    });

    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        expect(SourceLines.of(source).contents, splitMarkdownLines(source));
      });
    }
  });

  group('offsets', () {
    test('each start really is where the line begins', () {
      const source = 'alpha\r\nbeta\n\ngamma';
      final lines = SourceLines.of(source);
      for (var i = 0; i < lines.length; i++) {
        expect(
          source.substring(
            lines.starts[i],
            lines.starts[i] + lines.contents[i].length,
          ),
          lines.contents[i],
          reason: 'line $i does not sit at the offset reported for it',
        );
      }
    });

    test('a line index past the end is the end of the source', () {
      final lines = SourceLines.of('one\ntwo\n');
      expect(lines.offsetOfLine(lines.length), 8);
      expect(lines.offsetOfLine(999), 8);
    });

    test('an empty source has no lines and offset zero', () {
      final lines = SourceLines.of('');
      expect(lines.length, 0);
      expect(lines.offsetOfLine(0), 0);
    });
  });
}
