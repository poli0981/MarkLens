/// Search across the open set (`docs/08_SEARCH.md`, "Search open files").
///
/// Pure Dart, isolate-backed, and deliberately reading **straight from disk**:
/// a document does not need to be parsed or cached to be searched, and routing
/// a thousand files through the pipeline to find a word in three of them would
/// spend the whole budget on the files with no matches in them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// One match, located the way a file is located rather than the way a parsed
/// document is.
///
/// **Line and column index the file on disk**, not `DocModel.sanitizedSource`
/// — front matter is still in it, block HTML is not yet rewritten, and MDX is
/// not yet sanitized. That is why a hit carries no block index: it could not
/// have a correct one. Doc 08 records how a click resolves to a block.
typedef CrossSearchHit = ({int line, int column, String preview});

/// Every match in one file, in file order.
class FileHits {
  /// Creates a file's hits.
  const FileHits({
    required this.path,
    required this.hits,
    this.truncated = false,
  });

  /// The file, as it was handed in.
  final String path;

  /// Matches, in file order.
  final List<CrossSearchHit> hits;

  /// Whether [hitLimit] cut the list short.
  ///
  /// Reported rather than swallowed: a panel that silently shows fifty of nine
  /// thousand matches is a panel that lies about the document.
  final bool truncated;
}

/// What one search asked for.
typedef SearchRequest = ({
  List<String> paths,
  String query,
  bool caseSensitive,
});

/// Most matches kept per file.
///
/// A query matching nine thousand times in one file is a query whose answer is
/// "everywhere", and building nine thousand rows to say so helps nobody.
const int hitLimit = 50;

/// Longest preview line kept, in characters.
const int previewLimit = 200;

/// Runs a literal search over a list of files.
///
/// Literal, not regex: doc 08 keeps regex as a v1.x candidate, and a query
/// someone types into a search box should not quietly be a pattern.
class SearchService {
  /// Creates a search service.
  const SearchService();

  /// Searches [paths] for [query], off the UI isolate.
  ///
  /// Returns only files that matched, in the order they were given. An empty
  /// query returns nothing rather than everything.
  ///
  /// **There is no cancellation here**, and doc 08's "cancellation on query
  /// change" is the caller's: `Isolate.run` cannot be killed from outside, so
  /// `CrossSearchController` debounces the query and discards results from a
  /// run it no longer wants. Against the doc 00 budget — 1,000 files of ~10 KB
  /// in under 300 ms — a superseded run finishing on its own is cheaper than
  /// the machinery to stop it.
  Future<List<FileHits>> search({
    required List<String> paths,
    required String query,
    bool caseSensitive = false,
  }) {
    if (query.isEmpty || paths.isEmpty) {
      return Future<List<FileHits>>.value(const <FileHits>[]);
    }
    return Isolate.run(
      () => searchFiles((
        paths: paths,
        query: query,
        caseSensitive: caseSensitive,
      )),
    );
  }
}

/// The body of a search, as a top-level function so it can run in an isolate.
///
/// Also called directly by tests, which is the point of it being separable: a
/// scan is easier to reason about than a scan plus an isolate.
List<FileHits> searchFiles(SearchRequest request) {
  final results = <FileHits>[];
  final needle = request.caseSensitive
      ? request.query
      : request.query.toLowerCase();

  for (final path in request.paths) {
    final text = _read(path);
    if (text == null) {
      // A file that has gone, or that cannot be read, is not an error worth
      // failing a search over — the sidebar already badges it (doc 07).
      continue;
    }
    final hits = _scan(
      text: text,
      needle: needle,
      caseSensitive: request.caseSensitive,
    );
    if (hits.hits.isNotEmpty) {
      results.add(
        FileHits(path: path, hits: hits.hits, truncated: hits.truncated),
      );
    }
  }
  return results;
}

/// Reads [path] as text, or `null` when it cannot be read.
String? _read(String path) {
  try {
    // Lossy on purpose: an invalid byte is not a reason to skip a file the
    // reader can open, and the pipeline decodes it the same way (doc 04).
    return utf8.decode(File(path).readAsBytesSync(), allowMalformed: true);
  } on FileSystemException {
    return null;
  }
}

({List<CrossSearchHit> hits, bool truncated}) _scan({
  required String text,
  required String needle,
  required bool caseSensitive,
}) {
  final hits = <CrossSearchHit>[];
  final lines = const LineSplitter().convert(text);

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final haystack = caseSensitive ? line : line.toLowerCase();
    // Folding must be length-preserving or every column after a changed
    // character is wrong. `in_file_search.dart` records the same reasoning;
    // here the fallback is per line, so one odd line degrades alone.
    final searchable = haystack.length == line.length ? haystack : line;

    var from = 0;
    while (true) {
      final at = searchable.indexOf(needle, from);
      if (at < 0) {
        break;
      }
      if (hits.length >= hitLimit) {
        return (hits: hits, truncated: true);
      }
      hits.add((line: i, column: at, preview: _preview(line)));
      // Non-overlapping, exactly as find-in-file counts.
      from = at + needle.length;
    }
  }
  return (hits: hits, truncated: false);
}

/// The context line a result row shows.
///
/// Trimmed of leading indentation, because a match twelve levels deep in a
/// list would otherwise be a row of spaces, and capped so one minified line
/// cannot be the whole panel.
String _preview(String line) {
  final trimmed = line.trimLeft();
  return trimmed.length <= previewLimit
      ? trimmed
      : '${trimmed.substring(0, previewLimit)}…';
}
