import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';

import '../fixtures/generators.dart';

/// The torture corpus (`docs/12_TESTING.md`) and CLAUDE.md rule 9: assume every
/// input file is adversarial, and let none of them crash the app.
void main() {
  const corpusRoot = 'test/fixtures/torture';
  const pipeline = MarkdownPipeline();

  final fixtures =
      Directory(corpusRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md') || f.path.endsWith('.mdx'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  group('fixture integrity', () {
    // These assertions exist to catch git normalizing the bytes out from under
    // the corpus. Without them, .gitattributes could silently regress and the
    // decoder tests below would keep passing while testing nothing.
    test('the corpus is present', () {
      expect(
        fixtures.length,
        greaterThan(20),
        reason: 'torture corpus looks truncated',
      );
    });

    test('invalid_utf8.md really contains invalid UTF-8', () {
      final bytes = File('$corpusRoot/bytes/invalid_utf8.md').readAsBytesSync();
      expect(bytes, contains(0xFF), reason: '0xFF was normalized away');
      expect(bytes, contains(0x80), reason: 'lone continuation byte is gone');
    });

    test('crlf.md really contains CRLF', () {
      final bytes = File('$corpusRoot/bytes/crlf.md').readAsBytesSync();
      var crlf = 0;
      for (var i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == 0x0D && bytes[i + 1] == 0x0A) crlf++;
      }
      expect(
        crlf,
        greaterThan(3),
        reason: 'CRLF endings were normalized to LF — check .gitattributes',
      );
    });

    test('bom.md really starts with a UTF-8 BOM', () {
      final bytes = File('$corpusRoot/bytes/bom.md').readAsBytesSync();
      expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);
    });

    test('empty.md really is zero bytes', () {
      expect(File('$corpusRoot/bytes/empty.md').lengthSync(), 0);
    });
  });

  group('every fixture survives the pipeline', () {
    for (final fixture in fixtures) {
      final relative = fixture.path.replaceAll(r'\', '/');
      test(relative.substring(corpusRoot.length + 1), () {
        final doc = pipeline.parse(
          path: relative,
          bytes: fixture.readAsBytesSync(),
          isMdx: relative.endsWith('.mdx'),
        );
        expect(doc.path, relative);
        // Not "at least one block": an empty file, a file of blank lines and
        // a file of nothing but link reference definitions all legitimately
        // render as nothing. What must hold for every document is that the
        // blocks partition the source the renderer is given, so no offset is
        // left with nowhere to scroll to.
        if (doc.blocks.isNotEmpty) {
          expect(doc.blocks.first.startOffset, 0);
          for (var i = 0; i < doc.blocks.length - 1; i++) {
            expect(
              doc.blocks[i].endOffset,
              doc.blocks[i + 1].startOffset,
              reason: 'blocks $i and ${i + 1} leave a gap in the source',
            );
          }
          expect(doc.blocks.last.endOffset, doc.sanitizedSource.length);
        }
      });
    }
  });

  group('byte-level decoding', () {
    DocModel parseFixture(String name) => pipeline.parse(
      path: '$corpusRoot/bytes/$name',
      bytes: File('$corpusRoot/bytes/$name').readAsBytesSync(),
      isMdx: false,
    );

    test('a zero-byte file is an empty document, not an error', () {
      final doc = parseFixture('empty.md');
      expect(doc.sanitizedSource, isEmpty);
      expect(doc.notices, isEmpty);
    });

    test('a BOM is stripped and raises no notice', () {
      final doc = parseFixture('bom.md');
      expect(doc.sanitizedSource, startsWith('# Heading'));
      expect(doc.notices, isEmpty);
    });

    test('invalid UTF-8 degrades lossily with a notice', () {
      final doc = parseFixture('invalid_utf8.md');
      expect(
        doc.notices.map((n) => n.kind),
        contains(DocNoticeKind.invalidUtf8),
      );
      expect(doc.sanitizedSource, contains('�'));
      // The valid tail must survive intact rather than being discarded.
      expect(doc.sanitizedSource, contains('Tiếng Việt'));
    });

    test('CRLF and wide UTF-8 decode without a notice', () {
      expect(parseFixture('crlf.md').notices, isEmpty);
      expect(parseFixture('mixed_endings.md').notices, isEmpty);

      final wide = parseFixture('wide_utf8.md');
      expect(wide.notices, isEmpty);
      expect(wide.sanitizedSource, contains('🎉'));
      expect(wide.sanitizedSource, contains('日本語'));
    });
  });

  group('generated documents', () {
    test('the large document is about 1 MB and parses', () {
      final source = generateLargeDocument();
      // The generator counts characters; assert on the UTF-8 byte size, which
      // is what "1 MB document" means for a file on disk.
      final bytes = utf8.encode(source);
      expect(bytes.length, greaterThan(1024 * 1024));
      expect(bytes.length, lessThan(1300 * 1024));

      final doc = pipeline.parse(
        path: 'generated/large.md',
        bytes: bytes,
        isMdx: false,
      );
      expect(doc.blocks, isNotEmpty);
    });

    test('generation is deterministic', () {
      expect(generateLargeDocument().length, generateLargeDocument().length);
      expect(generateWideTable(), generateWideTable());
    });

    test('the wide table has 60 columns', () {
      final firstRow = generateWideTable().split('\n')[2];
      expect('|'.allMatches(firstRow).length, 61);
    });

    test('the tall table has 2000 body rows', () {
      final lines = generateTallTable().split('\n')
        ..removeWhere((l) => l.isEmpty);
      // heading + header row + divider + 2000 rows
      expect(lines.length, 2003);
    });

    test('10,000 sibling MDX components parse without recursion trouble', () {
      final source = generateManySiblingComponents();
      final doc = pipeline.parse(
        path: 'generated/siblings.mdx',
        bytes: utf8.encode(source),
        isMdx: true,
      );
      expect(doc.blocks, isNotEmpty);
    });
  });
}
