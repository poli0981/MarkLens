import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/pipeline.dart';
import 'package:marklens/core/models/doc_model.dart';

/// `docs/04_MARKDOWN_PIPELINE.md` stage 1, and CLAUDE.md rule 9: no input
/// makes decoding throw.
void main() {
  group('decodeSource', () {
    test('decodes plain UTF-8 without a notice', () {
      final result = MarkdownPipeline.decodeSource(utf8.encode('# Hello'));
      expect(result.text, '# Hello');
      expect(result.lossy, isFalse);
    });

    test('strips a UTF-8 BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('# Hello')];
      final result = MarkdownPipeline.decodeSource(bytes);
      expect(result.text, '# Hello');
      expect(result.lossy, isFalse);
    });

    test('keeps multibyte text intact', () {
      final result = MarkdownPipeline.decodeSource(utf8.encode('Tiếng Việt'));
      expect(result.text, 'Tiếng Việt');
      expect(result.lossy, isFalse);
    });

    test('decodes invalid UTF-8 lossily instead of throwing', () {
      // 0xFF never appears in valid UTF-8.
      final result = MarkdownPipeline.decodeSource(<int>[0x41, 0xFF, 0x42]);
      expect(result.lossy, isTrue);
      expect(result.text, contains('�'));
      expect(result.text, startsWith('A'));
    });

    test('an empty file is an empty document, not an error', () {
      final result = MarkdownPipeline.decodeSource(<int>[]);
      expect(result.text, isEmpty);
      expect(result.lossy, isFalse);
    });
  });

  group('MarkdownPipeline.parse', () {
    test('raises a notice for invalid UTF-8', () {
      const pipeline = MarkdownPipeline();
      final doc = pipeline.parse(
        path: '/tmp/bad.md',
        bytes: <int>[0xFF],
        isMdx: false,
      );
      expect(
        doc.notices.map((n) => n.kind),
        contains(DocNoticeKind.invalidUtf8),
      );
    });

    test('always yields at least one block to aim at', () {
      const pipeline = MarkdownPipeline();
      final doc = pipeline.parse(
        path: '/tmp/empty.md',
        bytes: <int>[],
        isMdx: false,
      );
      expect(doc.blocks, isNotEmpty);
      expect(doc.outline.isEmpty, isTrue);
    });
  });
}
