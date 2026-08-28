import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/search/search_service.dart';

/// `docs/08_SEARCH.md`, "Search open files", and `docs/12_TESTING.md`'s
/// "SearchService: hit mapping, cancellation, isolate round-trip".
///
/// Cancellation is the controller's, not this class's, and is covered in
/// `test/app/cross_search_test.dart` — `Isolate.run` cannot be killed from
/// outside, so what this file proves is that the scan itself is correct and
/// that it survives the round trip.
void main() {
  late Directory root;

  String at(String name) => '${root.path}${Platform.pathSeparator}$name';

  String write(String name, String content) {
    final path = at(name);
    File(path).writeAsStringSync(content);
    return path;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_search_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  List<FileHits> scan(
    List<String> paths,
    String query, {
    bool caseSensitive = false,
  }) => searchFiles((
    paths: paths,
    query: query,
    caseSensitive: caseSensitive,
  ));

  group('the scan', () {
    test('finds every match, with its line and a context line', () {
      final path = write('a.md', '# Title\n\nalpha here\n\nand alpha again\n');

      final results = scan(<String>[path], 'alpha');

      expect(results, hasLength(1));
      expect(results.single.path, path);
      expect(results.single.hits.map((h) => h.line), <int>[2, 4]);
      expect(results.single.hits.first.preview, 'alpha here');
      expect(results.single.hits.last.preview, 'and alpha again');
    });

    test('counts non-overlapping matches, as find-in-file does', () {
      final path = write('a.md', 'aaaa\n');

      expect(scan(<String>[path], 'aa').single.hits, hasLength(2));
    });

    test('several on one line each get a column', () {
      final path = write('a.md', 'x and x and x\n');

      final hits = scan(<String>[path], 'x').single.hits;

      expect(hits.map((h) => h.column), <int>[0, 6, 12]);
      expect(hits.every((h) => h.line == 0), isTrue);
    });

    test('is case-insensitive by default and exact when asked', () {
      final path = write('a.md', 'Alpha\nALPHA\nalpha\n');

      expect(scan(<String>[path], 'alpha').single.hits, hasLength(3));
      expect(
        scan(<String>[path], 'alpha', caseSensitive: true).single.hits,
        hasLength(1),
      );
    });

    test('files with no matches are absent, not empty', () {
      final hit = write('a.md', 'alpha\n');
      final miss = write('b.md', 'beta\n');

      final results = scan(<String>[hit, miss], 'alpha');

      expect(results.map((r) => r.path), <String>[hit]);
    });

    test('results keep the order they were asked for', () {
      final b = write('b.md', 'alpha\n');
      final a = write('a.md', 'alpha\n');

      expect(scan(<String>[b, a], 'alpha').map((r) => r.path), <String>[b, a]);
    });

    test('a preview is trimmed of indentation but keeps its shape', () {
      final path = write('a.md', '            - deep alpha item\n');

      expect(
        scan(<String>[path], 'alpha').single.hits.single.preview,
        '- deep alpha item',
      );
    });

    test('a very long line is capped rather than becoming the panel', () {
      final path = write('a.md', '${'x' * 5000}alpha\n');

      final preview = scan(<String>[path], 'alpha').single.hits.single.preview;

      expect(preview.length, lessThanOrEqualTo(previewLimit + 1));
      expect(preview, endsWith('…'));
    });
  });

  group('caps and failures are reported, never silent', () {
    test('past the per-file cap, the file says it was cut short', () {
      final path = write('a.md', 'alpha\n' * (hitLimit + 20));

      final file = scan(<String>[path], 'alpha').single;

      expect(file.hits, hasLength(hitLimit));
      expect(
        file.truncated,
        isTrue,
        reason: 'showing 50 of 70 without saying so lies about the document',
      );
    });

    test('a file that is not there is skipped, not fatal', () {
      final present = write('a.md', 'alpha\n');

      final results = scan(<String>[at('gone.md'), present], 'alpha');

      expect(results.map((r) => r.path), <String>[present]);
    });

    test('a directory in the list is skipped too', () {
      Directory(at('folder')).createSync();
      final present = write('a.md', 'alpha\n');

      expect(
        () => scan(<String>[at('folder'), present], 'alpha'),
        returnsNormally,
      );
    });

    test('invalid UTF-8 decodes lossily rather than skipping the file', () {
      // The same decision the pipeline makes (doc 04): a bad byte is not a
      // reason to pretend a file the reader can open does not exist.
      final path = at('bad.md');
      File(path).writeAsBytesSync(<int>[
        ...'alpha '.codeUnits,
        0xFF,
        0x80,
        ...' omega'.codeUnits,
      ]);

      expect(scan(<String>[path], 'omega').single.hits, hasLength(1));
    });
  });

  group('the isolate round trip', () {
    test('an empty query searches nothing', () async {
      final path = write('a.md', 'alpha\n');

      expect(
        await const SearchService().search(paths: <String>[path], query: ''),
        isEmpty,
      );
    });

    test('an empty file list searches nothing', () async {
      expect(
        await const SearchService().search(
          paths: const <String>[],
          query: 'alpha',
        ),
        isEmpty,
      );
    });

    test('hits survive being sent back across the boundary', () async {
      final a = write('a.md', 'first alpha\n');
      final b = write('b.md', 'no match here\n');
      final c = write('c.md', 'line one\nsecond alpha\n');

      final results = await const SearchService().search(
        paths: <String>[a, b, c],
        query: 'alpha',
      );

      expect(results.map((r) => r.path), <String>[a, c]);
      expect(results.last.hits.single.line, 1);
      expect(results.last.hits.single.preview, 'second alpha');
    });

    test('and the whole open set fits the doc 00 budget', () async {
      // 1,000 files of ~10 KB in under 300 ms on the reference machine
      // (docs/08_SEARCH.md). Asserted loosely here, because a CI runner is not
      // the reference machine and a tight bound would be a flake generator —
      // what this catches is an accidental quadratic, not a slow disk.
      final paths = <String>[
        for (var i = 0; i < 1000; i++)
          write('f$i.md', '${'filler line here\n' * 600}needle\n'),
      ];

      final stopwatch = Stopwatch()..start();
      final results = await const SearchService().search(
        paths: paths,
        query: 'needle',
      );
      stopwatch.stop();

      expect(results, hasLength(1000));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });
}
