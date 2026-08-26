import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/block_index.dart';
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

    test('an empty document yields no blocks and an empty outline', () {
      const pipeline = MarkdownPipeline();
      final doc = pipeline.parse(
        path: '/tmp/empty.md',
        bytes: <int>[],
        isMdx: false,
      );
      // "At least one block" was tempting and is wrong: the renderer builds
      // no children for an empty document either, and blocks[i] has to keep
      // meaning children[2i]. A file holding only blank lines or only link
      // reference definitions is empty in the same way.
      expect(doc.blocks, isEmpty);
      expect(doc.outline.isEmpty, isTrue);
      expect(doc.notices, isEmpty);
    });

    test('rawSource keeps the front matter that sanitizedSource drops', () {
      const source = '---\ntitle: kept\n---\n\n# Body\n';
      final doc = const MarkdownPipeline().parse(
        path: '/tmp/fm.md',
        bytes: utf8.encode(source),
        isMdx: false,
      );

      expect(doc.rawSource, source);
      expect(
        doc.sanitizedSource,
        isNot(contains('title: kept')),
        reason: 'the front matter must never reach the renderer (docs/04)',
      );
      expect(
        doc.frontMatter!.fields,
        <String, String>{'title': 'kept'},
      );
    });
  });

  group('degrading instead of failing (CLAUDE.md rule 9)', () {
    test('a parse that cannot be trusted becomes a plain-text notice', () {
      // The index reports `degraded` when the parse threw, or when a top-level
      // node came back with no source range — which would mean scroll targets
      // that are quietly wrong. Wrong targets are worse than none, so the
      // document is shown as plain text and the reader is told.
      const pipeline = MarkdownPipeline(blockIndexer: _DegradedIndexer());
      final doc = pipeline.parse(
        path: '/tmp/broken.md',
        bytes: utf8.encode('# Heading\n\nBody.\n'),
        isMdx: false,
      );

      expect(
        doc.notices.map((n) => n.kind),
        contains(DocNoticeKind.plainTextFallback),
      );
      expect(doc.blocks, isEmpty);
      expect(doc.outline.isEmpty, isTrue);
      expect(
        doc.sanitizedSource,
        contains('# Heading'),
        reason: 'the text is still shown; only the structure is disclaimed',
      );
    });

    test('a document over the large threshold is flagged, not refused', () {
      // The threshold is injected so this stays a unit test. Parsing ten real
      // megabytes to reach the default would add half a minute to every run
      // and would be measuring throughput, not the notice.
      const pipeline = MarkdownPipeline(largeDocumentBytes: 16);
      final doc = pipeline.parse(
        path: '/tmp/big.md',
        bytes: utf8.encode('# A heading that is over sixteen bytes long'),
        isMdx: false,
      );

      expect(
        doc.notices.map((n) => n.kind),
        contains(DocNoticeKind.largeDocument),
      );
      expect(
        doc.blocks,
        hasLength(1),
        reason: 'large is a notice, not a refusal — the document still renders',
      );
    });

    test('a document at the threshold is not flagged', () {
      const source = '# Small';
      final doc =
          MarkdownPipeline(
            largeDocumentBytes: utf8.encode(source).length,
          ).parse(
            path: '/tmp/borderline.md',
            bytes: utf8.encode(source),
            isMdx: false,
          );
      expect(doc.notices, isEmpty);
    });

    test('the default threshold is the one docs/04 states', () {
      expect(
        MarkdownPipeline.defaultLargeDocumentBytes,
        10 * 1024 * 1024,
        reason: 'docs/04: over 10 MB shows a banner, over 50 MB is refused',
      );
      expect(
        const MarkdownPipeline().largeDocumentBytes,
        MarkdownPipeline.defaultLargeDocumentBytes,
      );
    });
  });
}

/// An indexer that always reports a parse it cannot vouch for.
class _DegradedIndexer implements BlockIndexer {
  const _DegradedIndexer();

  @override
  BlockIndexResult index(String source) =>
      (blocks: const <SourceBlock>[], nodes: const <md.Node>[], degraded: true);
}
