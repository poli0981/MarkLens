/// `docs/02_ARCHITECTURE.md` (DocCache), CLAUDE.md rule 8 (LRU of parsed
/// documents, never widgets) and `docs/07_FILES_AND_WATCH.md` (the
/// `mtime + size` tuple that makes staleness structural).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/cache/doc_cache.dart';
import 'package:marklens/core/models/doc_model.dart';
import 'package:marklens/core/models/opened_file.dart';
import 'package:marklens/core/models/outline.dart';

OpenedFile _file(
  String identity, {
  DateTime? modified,
  int size = 10,
}) => OpenedFile(
  path: identity,
  identity: identity,
  modified: modified ?? DateTime(2026, 8, 26, 12),
  size: size,
);

DocModel _doc(String path) => DocModel(
  path: path,
  rawSource: '# $path',
  sanitizedSource: '# $path',
  outline: Outline.empty,
  blocks: const <SourceBlock>[],
);

void main() {
  group('holding and returning documents', () {
    test('a stored document comes back', () {
      final cache = DocCache();
      final key = DocCache.keyFor(_file('/a.md'));

      expect(cache.get(key), isNull);
      cache.put(key, _doc('/a.md'));
      expect(cache.get(key)!.path, '/a.md');
      expect(cache.length, 1);
    });

    test('storing the same key twice does not grow the cache', () {
      final cache = DocCache();
      final key = DocCache.keyFor(_file('/a.md'));

      cache
        ..put(key, _doc('/a.md'))
        ..put(key, _doc('/a.md'));
      expect(cache.length, 1);
    });
  });

  group('the key makes staleness structural', () {
    test('a changed mtime misses', () {
      final cache = DocCache();
      final before = _file('/a.md', modified: DateTime(2026, 8, 26, 12));
      final after = _file('/a.md', modified: DateTime(2026, 8, 26, 13));

      cache.put(DocCache.keyFor(before), _doc('/a.md'));
      expect(cache.get(DocCache.keyFor(after)), isNull);
    });

    test('a same-mtime rewrite of a different length misses', () {
      final cache = DocCache();
      final before = _file('/a.md');
      final after = _file('/a.md', size: 11);

      cache.put(DocCache.keyFor(before), _doc('/a.md'));
      expect(
        cache.get(DocCache.keyFor(after)),
        isNull,
        reason:
            'size is in the key precisely because a rewrite can land inside '
            'one filesystem timestamp tick — mtime alone would serve the old '
            'parse of a file that has changed',
      );
    });

    test('a different settings revision misses', () {
      final cache = DocCache();
      final file = _file('/a.md');

      cache.put(DocCache.keyFor(file), _doc('/a.md'));
      expect(cache.get(DocCache.keyFor(file, settingsRevision: 1)), isNull);
    });

    test('two paths to the same file are one entry', () {
      final cache = DocCache();
      const shared = '/real/a.md';
      final direct = OpenedFile(
        path: shared,
        identity: shared,
        modified: DateTime(2026, 8, 26),
        size: 10,
      );
      final viaLink = OpenedFile(
        path: '/link/a.md',
        identity: shared,
        modified: DateTime(2026, 8, 26),
        size: 10,
      );

      cache.put(DocCache.keyFor(direct), _doc(shared));
      expect(
        cache.get(DocCache.keyFor(viaLink)),
        isNotNull,
        reason:
            'identity is the canonical path, so a symlink and its target are '
            'one document and must not be parsed or cached twice',
      );
    });
  });

  group('eviction is least-recently-used', () {
    test('the oldest goes when the cache is full', () {
      final cache = DocCache(capacity: 2);
      final a = DocCache.keyFor(_file('/a.md'));
      final b = DocCache.keyFor(_file('/b.md'));
      final c = DocCache.keyFor(_file('/c.md'));

      cache
        ..put(a, _doc('/a.md'))
        ..put(b, _doc('/b.md'))
        ..put(c, _doc('/c.md'));

      expect(cache.length, 2);
      expect(cache.get(a), isNull);
      expect(cache.get(b), isNotNull);
      expect(cache.get(c), isNotNull);
    });

    test('reading an entry makes it the newest', () {
      final cache = DocCache(capacity: 2);
      final a = DocCache.keyFor(_file('/a.md'));
      final b = DocCache.keyFor(_file('/b.md'));
      final c = DocCache.keyFor(_file('/c.md'));

      cache
        ..put(a, _doc('/a.md'))
        ..put(b, _doc('/b.md'))
        ..get(a)
        ..put(c, _doc('/c.md'));

      expect(
        cache.get(a),
        isNotNull,
        reason: 'a was used most recently, so b is the one that goes',
      );
      expect(cache.get(b), isNull);
    });

    test('re-storing an entry also makes it the newest', () {
      final cache = DocCache(capacity: 2);
      final a = DocCache.keyFor(_file('/a.md'));
      final b = DocCache.keyFor(_file('/b.md'));
      final c = DocCache.keyFor(_file('/c.md'));

      cache
        ..put(a, _doc('/a.md'))
        ..put(b, _doc('/b.md'))
        ..put(a, _doc('/a.md'))
        ..put(c, _doc('/c.md'));

      expect(cache.get(a), isNotNull);
      expect(cache.get(b), isNull);
    });

    test('the default capacity is the one docs/02 states', () {
      expect(DocCache.defaultCapacity, 40);
      expect(DocCache().capacity, 40);
    });

    test('filling past the default evicts down to it', () {
      final cache = DocCache();
      for (var i = 0; i < 45; i++) {
        cache.put(DocCache.keyFor(_file('/doc$i.md')), _doc('/doc$i.md'));
      }
      expect(cache.length, 40);
      expect(cache.get(DocCache.keyFor(_file('/doc0.md'))), isNull);
      expect(cache.get(DocCache.keyFor(_file('/doc44.md'))), isNotNull);
    });
  });

  group('invalidation', () {
    test('drops every parse of one document', () {
      final cache = DocCache();
      final file = _file('/a.md');

      cache
        ..put(DocCache.keyFor(file), _doc('/a.md'))
        ..put(DocCache.keyFor(file, settingsRevision: 1), _doc('/a.md'))
        ..put(DocCache.keyFor(_file('/b.md')), _doc('/b.md'));

      expect(cache.invalidate('/a.md'), 2);
      expect(cache.length, 1);
      expect(cache.get(DocCache.keyFor(_file('/b.md'))), isNotNull);
    });

    test('invalidating something absent is harmless', () {
      final cache = DocCache();
      expect(cache.invalidate('/nothing.md'), 0);
    });

    test('clear empties it', () {
      final cache = DocCache()
        ..put(DocCache.keyFor(_file('/a.md')), _doc('/a.md'))
        ..clear();
      expect(cache.length, 0);
    });
  });
}
