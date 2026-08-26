/// Shared discovery for the torture corpus (`docs/12_TESTING.md`).
///
/// Every `.md`/`.mdx` under `test/fixtures/torture/` is a test case, so adding
/// a fixture adds cases to every suite that walks this list. Kept in its own
/// library — with no `main()` — for the same reason
/// `test/architecture/source_scan.dart` is: the helper is shared, and a helper
/// that is itself a test file would run its own cases in every suite that
/// imports it.
library;

import 'dart:convert';
import 'dart:io';

/// One file in the torture corpus.
class TortureFixture {
  /// Wraps [file], which must live under [corpusRoot].
  TortureFixture(this.file);

  /// The fixture on disk.
  final File file;

  /// Path relative to [corpusRoot], with `/` separators on both platforms so
  /// assertions and test names read identically on Windows and Ubuntu.
  String get relativePath =>
      file.path.replaceAll(r'\', '/').split('$corpusRoot/').last;

  /// Whether the MDX branch of the pipeline applies — by extension alone,
  /// never by sniffing content (`docs/04_MARKDOWN_PIPELINE.md`).
  bool get isMdx => relativePath.endsWith('.mdx');

  /// The raw bytes, which is what the pipeline actually takes.
  List<int> readAsBytes() => file.readAsBytesSync();

  /// The decoded text, lossily so the deliberately-invalid fixture is usable
  /// here rather than throwing.
  String readAsString() => utf8.decode(readAsBytes(), allowMalformed: true);
}

/// Root of the corpus, relative to the package directory tests run from.
const String corpusRoot = 'test/fixtures/torture';

/// Every fixture, in a stable order.
List<TortureFixture> tortureFixtures() =>
    Directory(corpusRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md') || f.path.endsWith('.mdx'))
        .map(TortureFixture.new)
        .toList()
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
