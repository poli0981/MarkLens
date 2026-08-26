/// `docs/04_MARKDOWN_PIPELINE.md` ("Why the source is parsed twice") and
/// `docs/spike-results/S1-renderer-bakeoff.md` Result 4.
///
/// The pipeline parses the source for the block index and the outline, and
/// `flutter_markdown_plus` parses the same source again for the widgets. The
/// reader maps `blocks[i]` onto `children[2i]`, so the two parses must produce
/// the same top-level nodes in the same order. Two things can break that, and
/// this file is the only thing that would notice either one:
///
/// 1. `defaultBlockSyntaxes()` is a hand-copy of a list that lives inside
///    `markdown`'s `BlockParser` as an instance member marked `@Deprecated`,
///    so it cannot be referenced directly. A package bump can change it.
/// 2. `buildMarkdownDocument()` claims to mirror the renderer's own
///    `md.Document(...)` construction. Nothing but a test holds that claim.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:marklens/core/markdown/markdown_flavor.dart';
import 'package:marklens/core/markdown/recording_syntaxes.dart';

import '../fixtures/generators.dart';
import 'corpus.dart';

/// A comparable shape for a top-level node: enough to catch a segmentation
/// difference, without depending on inline parsing details.
String _shape(md.Node node) => switch (node) {
  md.Element(:final tag, :final children) => '$tag/${children?.length ?? -1}',
  md.Text() => '#text',
  _ => node.runtimeType.toString(),
};

List<String> _shapes(List<md.Node> nodes) => nodes.map(_shape).toList();

/// Exactly what `MarkdownWidget._parseMarkdown` does in
/// `flutter_markdown_plus 1.0.12`, transcribed verbatim so the comparison is
/// against the renderer's real construction rather than against our idea of it.
List<md.Node> _rendererParse(String source) => md.Document(
  // The two nulls match the package defaults, and are written out anyway:
  // this is a transcription, and the value of a transcription is that it can
  // be diffed against the original when the package moves.
  // ignore: avoid_redundant_argument_values
  blockSyntaxes: null,
  // Same reason as above.
  // ignore: avoid_redundant_argument_values
  inlineSyntaxes: null,
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(const LineSplitter().convert(source));

/// Whether [node] is the footnote section `Document` synthesizes at the end of
/// a document that has footnote definitions.
bool isSynthesizedFootnoteSection(md.Node node) =>
    node is md.Element &&
    node.tag == 'section' &&
    node.attributes['class'] == 'footnotes';

/// The same source through the position-recording subclasses, which is what
/// `BlockIndexer` actually runs.
List<md.Node> _recordingParse(String source, BlockSpanRecorder recorder) =>
    parseRecording(splitMarkdownLines(source), recorder);

/// The same source through our hand-copied syntax list.
List<md.Node> _mirroredParse(String source) =>
    buildMarkdownDocument(blockSyntaxes: defaultBlockSyntaxes())
        .parseLines(const LineSplitter().convert(source));

void main() {
  group('buildMarkdownDocument mirrors the renderer', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        expect(
          _shapes(parseMarkdown(source)),
          _shapes(_rendererParse(source)),
          reason:
              'core and the renderer disagree on the top-level block list for '
              '${fixture.relativePath}, so blocks[i] no longer lines up with '
              'children[2i] — see docs/04 "Why the source is parsed twice"',
        );
      });
    }
  });

  group('defaultBlockSyntaxes has not drifted from the package', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        expect(
          _shapes(_mirroredParse(source)),
          _shapes(_rendererParse(source)),
          reason:
              'the hand-copied syntax list in markdown_flavor.dart no longer '
              "reproduces markdown 7.3.1's own default list. Re-read "
              'BlockParser.standardBlockSyntaxes and Document.new, and update '
              'defaultBlockSyntaxes() to match.',
        );
      });
    }

    test('large generated document', () {
      final source = generateLargeDocument();
      expect(_shapes(_mirroredParse(source)), _shapes(_rendererParse(source)));
    });

    test('wide table', () {
      final source = generateWideTable();
      expect(_shapes(_mirroredParse(source)), _shapes(_rendererParse(source)));
    });

    test('tall table', () {
      final source = generateTallTable();
      expect(_shapes(_mirroredParse(source)), _shapes(_rendererParse(source)));
    });
  });

  group('the recording subclasses change nothing but bookkeeping', () {
    for (final fixture in tortureFixtures()) {
      test(fixture.relativePath, () {
        final source = fixture.readAsString();
        final recorder = BlockSpanRecorder();
        final nodes = _recordingParse(source, recorder);

        expect(
          _shapes(nodes),
          _shapes(_rendererParse(source)),
          reason:
              'recording the block positions changed what the parser produces '
              'for ${fixture.relativePath}. The subclasses must only observe; '
              'if one of them alters parsing, the block index describes a '
              'document the reader never sees.',
        );

        // The hoisted footnote section is the one node with no source
        // position under any design: `Document` synthesizes it after parsing,
        // out of definitions it lifted from elsewhere in the file.
        // `BlockIndexer` gives it an explicit empty range at the end.
        final unrecorded = nodes
            .where((node) => recorder.spanOf(node) == null)
            .where((node) => !isSynthesizedFootnoteSection(node))
            .map(_shape)
            .toList();
        expect(
          unrecorded,
          isEmpty,
          reason:
              'these top-level nodes came back without a source range, so '
              'nothing can scroll to them: $unrecorded',
        );
      });
    }
  });

  group('the hand-copied syntax list matches the package list', () {
    test('same types, same order', () {
      final parser = md.BlockParser(<md.Line>[], md.Document());
      // The package's own default list is an instance member marked
      // @Deprecated, so lib/ cannot reference it. Reading it here is the whole
      // point of this test: it is the only place the copy in
      // markdown_flavor.dart can be checked against its original.
      // ignore: deprecated_member_use
      final packageDefaults = parser.standardBlockSyntaxes;

      expect(
        defaultBlockSyntaxes().map((s) => s.runtimeType).toList(),
        <Type>[
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes.map(
            (s) => s.runtimeType,
          ),
          ...packageDefaults.map((s) => s.runtimeType),
        ],
        reason:
            'defaultBlockSyntaxes() in markdown_flavor.dart no longer copies '
            "markdown 7.3.1's own list. Re-read Document.new and "
            'BlockParser.standardBlockSyntaxes, then re-mirror it — and check '
            'recordingBlockSyntaxes() in the same pass, since it mirrors the '
            'same order.',
      );
    });

    test('the recording list mirrors it position for position', () {
      final recording = recordingBlockSyntaxes(BlockSpanRecorder());
      final plain = defaultBlockSyntaxes();

      expect(recording.length, plain.length);
      for (var i = 0; i < plain.length; i++) {
        final plainName = plain[i].runtimeType.toString();
        final recordingName = recording[i].runtimeType.toString();
        expect(
          recordingName == plainName || recordingName == '_Recording$plainName',
          isTrue,
          reason:
              'recordingBlockSyntaxes()[$i] is a $recordingName where '
              'defaultBlockSyntaxes()[$i] is a $plainName. The two lists must '
              'stay position for position, or the block index describes a '
              'different parse than the mirror test checks.',
        );
      }
    });
  });
}
