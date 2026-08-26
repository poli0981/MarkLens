/// `docs/07_FILES_AND_WATCH.md`: the extension registry, the folder scan, the
/// soft cap, identity, and the `mtime + size` change tuple.
///
/// Against a real temporary directory rather than an injected filesystem. The
/// rules being tested — symlink handling, canonical identity, hidden entries —
/// are rules *about* a filesystem, and a fake one would only prove that the
/// fake agrees with the code.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/files/file_service.dart';
import 'package:marklens/core/models/opened_file.dart';

void main() {
  late Directory root;
  const service = FileService();

  String at(String relative) =>
      '${root.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}';

  void writeFile(String relative, [String content = 'x']) {
    final file = File(at(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  /// Creates a symlink, or returns false when the platform will not allow it.
  ///
  /// Windows needs Developer Mode or elevation for this, so the symlink tests
  /// report themselves as skipped rather than failing on a machine that simply
  /// cannot make one.
  bool tryLink(String relative, String target) {
    try {
      Link(at(relative)).createSync(target);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_files_');
    writeFile('2.md');
    writeFile('10.md');
    writeFile('README.MD');
    writeFile('image.png');
    writeFile('notes.txt');
    writeFile('.hidden.md');
    writeFile('.git/ignored.md');
    writeFile('sub/a.md');
    writeFile('sub/deep/b.md');
    Directory(at('empty-dir')).createSync();
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  List<String> namesFrom(ScanResult result) =>
      result.files.map((f) => f.name).toList();

  group('what a scan collects', () {
    test('only the registered extensions, case-insensitively', () {
      final names = namesFrom(service.scanRoots(<String>[root.path]));

      expect(names, contains('README.MD'));
      expect(names, isNot(contains('image.png')));
      expect(names, isNot(contains('notes.txt')));
    });

    test('hidden files and hidden directories are skipped', () {
      final names = namesFrom(service.scanRoots(<String>[root.path]));

      expect(names, isNot(contains('.hidden.md')));
      expect(
        names,
        isNot(contains('ignored.md')),
        reason: 'a .git directory is never descended into',
      );
    });

    test('breadth-first, natural sort, directories before files', () {
      expect(namesFrom(service.scanRoots(<String>[root.path])), <String>[
        // Root files first, `2` before `10`.
        '2.md',
        '10.md',
        'README.MD',
        // Then one level down, then two.
        'a.md',
        'b.md',
      ]);
    });

    test('an empty directory contributes nothing and breaks nothing', () {
      expect(service.scanRoots(<String>[root.path]).files, hasLength(5));
    });

    test('a root that does not exist yields nothing rather than throwing', () {
      expect(
        service.scanRoots(<String>[at('no-such-folder')]).files,
        isEmpty,
      );
    });

    test('an empty root list is not an error', () {
      final result = service.scanRoots(const <String>[]);
      expect(result.files, isEmpty);
      expect(result.capExceeded, isFalse);
    });

    test('a custom registry changes what counts', () {
      final txtOnly = FileService(registry: ExtensionRegistry(<String>['txt']));
      expect(namesFrom(txtOnly.scanRoots(<String>[root.path])), <String>[
        'notes.txt',
      ]);
    });
  });

  group('the soft cap', () {
    test('reports rather than truncating silently', () {
      const capped = FileService(fileCap: 2);
      final result = capped.scanRoots(<String>[root.path]);

      expect(result.files, hasLength(2));
      expect(
        result.capExceeded,
        isTrue,
        reason:
            'the caller has to be able to offer "Open first N / Cancel"; a '
            'silent truncation looks exactly like a folder with two files',
      );
    });

    test('a folder exactly at the cap is not flagged', () {
      const capped = FileService(fileCap: 5);
      final result = capped.scanRoots(<String>[root.path]);

      expect(result.files, hasLength(5));
      expect(result.capExceeded, isFalse);
    });
  });

  group('identity', () {
    test('the same root twice yields each file once', () {
      final result = service.scanRoots(<String>[root.path, root.path]);
      expect(result.files, hasLength(5));
    });

    test('a nested root does not duplicate its parent"s files', () {
      final result = service.scanRoots(<String>[root.path, at('sub')]);
      expect(namesFrom(result), <String>[
        '2.md',
        '10.md',
        'README.MD',
        'a.md',
        'b.md',
      ]);
    });

    test('identity is stable across scans', () {
      final first = service.scanRoots(<String>[root.path]).files;
      final second = service.scanRoots(<String>[root.path]).files;
      expect(
        first.map((f) => f.identity),
        second.map((f) => f.identity),
      );
    });

    test('the displayed path keeps its on-disk casing', () {
      final readme = service
          .scanRoots(<String>[root.path])
          .files
          .firstWhere((f) => f.name.toLowerCase() == 'readme.md');
      expect(
        readme.path,
        endsWith('README.MD'),
        reason:
            'identity is case-folded, the path shown to the user is not — the '
            'sidebar must not lower-case the folders someone named',
      );
    });
  });

  group('symlinks', () {
    test('a symlinked directory is skipped for cycle safety', () {
      if (!tryLink('loop', root.path)) {
        return;
      }
      // Without the skip this walk would not terminate.
      final result = service.scanRoots(<String>[root.path]);
      expect(namesFrom(result), <String>[
        '2.md',
        '10.md',
        'README.MD',
        'a.md',
        'b.md',
      ]);
    }, skip: !_canLink);

    test('a symlinked file is followed, and deduped against its target', () {
      if (!tryLink('alias.md', at('sub/a.md'))) {
        return;
      }
      final result = service.scanRoots(<String>[root.path]);
      expect(
        result.files.where((f) => f.identity.endsWith('a.md')),
        hasLength(1),
        reason: 'the link and its target are one document, not two',
      );
    }, skip: !_canLink);

    test('a link pointing at nothing is skipped, not fatal', () {
      if (!tryLink('broken.md', at('gone.md'))) {
        return;
      }
      expect(service.scanRoots(<String>[root.path]).files, hasLength(5));
    }, skip: !_canLink);
  });

  group('describing one file', () {
    test('extension filtering does not apply — user intent wins', () {
      final entry = service.describe(at('image.png'));
      expect(
        entry,
        isNotNull,
        reason:
            'a file named on the command line opens even if a scan would not '
            'have found it (docs/07)',
      );
      expect(entry!.name, 'image.png');
    });

    test('a directory is not a document', () {
      expect(service.describe(at('sub')), isNull);
    });

    test('a path that does not exist is not a document', () {
      expect(service.describe(at('gone.md')), isNull);
    });

    test('an empty path is not a document', () {
      expect(service.describe('   '), isNull);
    });

    test('size and modified time come back', () {
      writeFile('sized.md', 'hello');
      final entry = service.describe(at('sized.md'))!;
      expect(entry.size, 5);
      expect(entry.modified.isAfter(DateTime(2000)), isTrue);
    });
  });

  group('the mtime + size tuple', () {
    late OpenedFile entry;

    setUp(() {
      writeFile('watched.md', 'one');
      entry = service.describe(at('watched.md'))!;
    });

    test('a file that disappears keeps its entry and gains the flag', () {
      File(at('watched.md')).deleteSync();
      final refreshed = service.refresh(entry);

      expect(refreshed.missing, isTrue);
      expect(
        refreshed.path,
        entry.path,
        reason: 'entries leave the session only when the user closes them',
      );
      expect(refreshed.identity, entry.identity);
    });

    test('a file that reappears clears the flag', () {
      File(at('watched.md')).deleteSync();
      final gone = service.refresh(entry);
      writeFile('watched.md', 'one again');

      final back = service.refresh(gone);
      expect(back.missing, isFalse);
      expect(back.size, 9);
    });

    test('a same-length rewrite is caught by mtime', () async {
      // Same size, so only the timestamp can tell. Filesystem timestamps are
      // coarse, so wait past the tick rather than racing it.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      writeFile('watched.md', 'two');

      expect(
        service.hasChanged(entry),
        isTrue,
        reason: 'three bytes replaced by three different bytes is a change',
      );
    });

    test('a different-length rewrite is caught by size', () {
      writeFile('watched.md', 'a much longer body than before');
      expect(service.hasChanged(entry), isTrue);
    });

    test('an untouched file has not changed', () {
      expect(service.hasChanged(entry), isFalse);
    });

    test('a disappearance counts as a change', () {
      File(at('watched.md')).deleteSync();
      expect(service.hasChanged(entry), isTrue);
    });
  });

  group('scanning off the UI isolate', () {
    test('gives the same answer as scanning in place', () async {
      final direct = service.scanRoots(<String>[root.path]);
      final background = await service.scanRootsInBackground(<String>[
        root.path,
      ]);

      expect(
        background.files.map((f) => f.path),
        direct.files.map((f) => f.path),
      );
      expect(background.capExceeded, direct.capExceeded);
    });

    test('the registry crosses the isolate boundary intact', () async {
      final txtOnly = FileService(registry: ExtensionRegistry(<String>['txt']));
      final result = await txtOnly.scanRootsInBackground(<String>[root.path]);
      expect(result.files.map((f) => f.name), <String>['notes.txt']);
    });
  });
}

/// Whether this machine can make symlinks at all.
///
/// Windows needs Developer Mode or an elevated prompt, and a developer without
/// either should see these reported as skipped rather than failing.
final bool _canLink = () {
  final probe = Directory.systemTemp.createTempSync('marklens_link_probe_');
  try {
    Link('${probe.path}${Platform.pathSeparator}l').createSync(probe.path);
    return true;
  } on FileSystemException {
    return false;
  } finally {
    probe.deleteSync(recursive: true);
  }
}();
