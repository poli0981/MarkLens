/// `docs/07_FILES_AND_WATCH.md` extension registry: one answer to "is this
/// ours", shared by folder scans, the file dialog, drag-drop and CLI args.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/files/extension_registry.dart';

void main() {
  group('the default set', () {
    const registry = ExtensionRegistry.standard;

    test('accepts every extension docs/05 lists', () {
      for (final extension in <String>[
        'md',
        'mdx',
        'markdown',
        'mdown',
        'mkd',
        'mkdn',
        'mdwn',
      ]) {
        expect(
          registry.allows('/docs/note.$extension'),
          isTrue,
          reason: '.$extension is in the default registry',
        );
      }
    });

    test('is case-insensitive', () {
      expect(registry.allows('/docs/README.MD'), isTrue);
      expect(registry.allows('/docs/Notes.MarkDown'), isTrue);
    });

    test('rejects everything else', () {
      for (final path in <String>[
        '/docs/image.png',
        '/docs/notes.txt',
        '/docs/archive.md.zip',
        '/docs/README',
        '/docs/.gitignore',
        '/docs/trailing.',
      ]) {
        expect(registry.allows(path), isFalse, reason: '$path is not a doc');
      }
    });

    test('mdx is recognised for the sanitizer, by extension alone', () {
      expect(registry.isMdx('/docs/page.mdx'), isTrue);
      expect(registry.isMdx('/docs/page.MDX'), isTrue);
      expect(registry.isMdx('/docs/page.md'), isFalse);
    });
  });

  group('a user-edited set', () {
    test('normalizes dots, case and whitespace', () {
      final registry = ExtensionRegistry(<String>['.TXT', 'md ', '..Rst']);
      expect(registry.extensions, <String>['txt', 'md', 'rst']);
      expect(registry.allows('/notes/a.txt'), isTrue);
      expect(registry.allows('/notes/a.rst'), isTrue);
      expect(registry.allows('/notes/a.mdx'), isFalse);
    });

    test('drops duplicates and empty entries', () {
      final registry = ExtensionRegistry(<String>['md', '.md', 'MD', '', '  ']);
      expect(registry.extensions, <String>['md']);
    });

    test('an empty set opens nothing', () {
      final registry = ExtensionRegistry(const <String>[]);
      expect(registry.allows('/notes/a.md'), isFalse);
    });
  });

  group('taking a path apart', () {
    test('basename accepts either separator', () {
      expect(ExtensionRegistry.basenameOf(r'C:\docs\note.md'), 'note.md');
      expect(ExtensionRegistry.basenameOf('/docs/note.md'), 'note.md');
      expect(
        ExtensionRegistry.basenameOf(r'C:\docs/mixed\note.md'),
        'note.md',
        reason:
            'Windows accepts forward slashes, and a path can arrive from a '
            'session file written on the other operating system',
      );
    });

    test('basename ignores a trailing separator', () {
      expect(ExtensionRegistry.basenameOf('/docs/sub/'), 'sub');
      expect(ExtensionRegistry.basenameOf(r'C:\docs\sub\'), 'sub');
    });

    test('basename of a bare name is the name', () {
      expect(ExtensionRegistry.basenameOf('note.md'), 'note.md');
      expect(ExtensionRegistry.basenameOf(''), '');
    });

    test('a dotfile has a name, not an extension', () {
      expect(ExtensionRegistry.extensionOf('/docs/.gitignore'), '');
      expect(
        ExtensionRegistry.extensionOf('/docs/.config.md'),
        'md',
        reason: 'a dotfile can still have a real extension after its name',
      );
    });

    test('a trailing dot is not an extension', () {
      expect(ExtensionRegistry.extensionOf('/docs/note.'), '');
    });

    test('the last dot wins', () {
      expect(ExtensionRegistry.extensionOf('/docs/a.b.markdown'), 'markdown');
    });

    test('a dot in a directory name is not the file extension', () {
      expect(
        ExtensionRegistry.extensionOf('/my.docs/README'),
        '',
        reason: 'the dot belongs to the folder, and README has no extension',
      );
    });
  });

  group('hidden entries', () {
    test('dot-prefixed names are hidden', () {
      expect(ExtensionRegistry.isHidden('/docs/.git'), isTrue);
      expect(ExtensionRegistry.isHidden(r'C:\docs\.hidden.md'), isTrue);
    });

    test('a dot inside the name does not hide it', () {
      expect(ExtensionRegistry.isHidden('/docs/release.notes.md'), isFalse);
    });

    test('a dot in a parent directory does not hide the child', () {
      expect(
        ExtensionRegistry.isHidden('/.config/notes.md'),
        isFalse,
        reason:
            'only the entry itself is judged; the scan skips the hidden '
            'directory before it ever looks inside it',
      );
    });
  });
}
