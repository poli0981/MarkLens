/// The two seams over `file_picker`, driven against a recording platform.
///
/// Every other test hands the shell a stub prompt, because a platform channel
/// does not exist inside a test. So until this file, the only code in the app
/// that talks to the plugin — `PlatformFilePickerPrompt` and
/// `PlatformSaveFilePrompt` — was checked by the compiler and nothing else,
/// which held exactly until `file_picker` 13 changed the facade underneath it
/// (doc 01). A fake `FilePickerPlatform` sits *below* that facade, so what is
/// asserted here is what the plugin is actually asked for — the filter, the
/// window lock, the bytes — and how each answer comes back, the cancelled
/// dialog included.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/open_files.dart';
import 'package:marklens/app/save_file.dart';
import 'package:marklens/core/files/extension_registry.dart';

/// A file the platform "picked". Only [name] and [uri] are real, and
/// `PlatformFile` derives `path` from [uri] itself — which is part of what is
/// under test: a `content:` URI has no path.
final class _PickedFile extends PlatformFile {
  new(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  // `xFile`, `length` and the readers. The prompts never call them, and
  // `XFile` is not exported by file_picker, so they are not spelled out.
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Records what the facade asks for and answers with what the test set.
class _RecordingPlatform extends FilePickerPlatform {
  List<PlatformFile> picked = <PlatformFile>[];
  String? directory;
  Uri? saved;

  FileType? type;
  List<String>? allowedExtensions;
  WindowsOptions? windowsOptions;
  LinuxOptions? linuxOptions;
  String? fileName;
  Uint8List? bytes;
  String? mimeType;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.windowsOptions = windowsOptions;
    this.linuxOptions = linuxOptions;
    return picked;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.windowsOptions = windowsOptions;
    this.linuxOptions = linuxOptions;
    return directory;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.fileName = fileName;
    this.bytes = bytes;
    this.mimeType = mimeType;
    this.windowsOptions = windowsOptions;
    this.linuxOptions = linuxOptions;
    return saved;
  }
}

void main() {
  late FilePickerPlatform original;
  late _RecordingPlatform platform;

  setUp(() {
    original = FilePickerPlatform.instance;
    platform = _RecordingPlatform();
    FilePickerPlatform.instance = platform;
  });

  tearDown(() {
    FilePickerPlatform.instance = original;
  });

  group('PlatformFilePickerPrompt', () {
    test('filters by the registry and locks the window, both OSes', () async {
      await const PlatformFilePickerPrompt().pickDocuments(
        ExtensionRegistry(const <String>['md', 'mdx']),
      );

      // One answer to "is this ours", for the dialog and the folder scan alike
      // (docs/07_FILES_AND_WATCH.md).
      expect(platform.type, FileType.custom);
      expect(platform.allowedExtensions, <String>['md', 'mdx']);
      expect(platform.windowsOptions?.lockParentWindow, isTrue);
      expect(platform.linuxOptions?.lockParentWindow, isTrue);
    });

    test('answers with the paths picked, dropping one that has none', () async {
      final onDisk = Uri.file('/docs/notes.md', windows: false);
      platform.picked = <PlatformFile>[
        _PickedFile('notes.md', onDisk),
        // What a sandboxed source can hand back: a document, but no path the
        // open set could watch or reload.
        _PickedFile('shared.md', Uri.parse('content://provider/shared.md')),
      ];

      final paths = await const PlatformFilePickerPrompt().pickDocuments(
        ExtensionRegistry(),
      );

      expect(paths, <String>[onDisk.toFilePath()]);
    });

    test('a cancelled dialog is an empty list, not a null', () async {
      final paths = await const PlatformFilePickerPrompt().pickDocuments(
        ExtensionRegistry(),
      );

      expect(paths, isEmpty);
    });

    test('a folder comes back as chosen, a cancel as null', () async {
      platform.directory = '/docs';
      expect(await const PlatformFilePickerPrompt().pickFolder(), '/docs');
      expect(platform.windowsOptions?.lockParentWindow, isTrue);
      expect(platform.linuxOptions?.lockParentWindow, isTrue);

      platform.directory = null;
      expect(await const PlatformFilePickerPrompt().pickFolder(), isNull);
    });
  });

  group('PlatformSaveFilePrompt', () {
    test(
      'names the file, hands over the bytes, and locks the window',
      () async {
        final bytes = utf8.encode('2026-10-26 12:00 info started');

        await const PlatformSaveFilePrompt().save(
          suggestedName: 'marklens-log',
          extension: 'txt',
          bytes: bytes,
        );

        // The extension travels in the name: saveFile never read a type filter,
        // which is why file_picker 13.2 deprecated passing one.
        expect(platform.fileName, 'marklens-log.txt');
        expect(platform.bytes, bytes);
        expect(platform.mimeType, 'text/plain');
        expect(platform.windowsOptions?.lockParentWindow, isTrue);
        expect(platform.linuxOptions?.lockParentWindow, isTrue);
      },
    );

    test('a file URI comes back as a path a person can read', () async {
      final written = Uri.file('/home/me/marklens-log.txt', windows: false);
      platform.saved = written;

      final shown = await const PlatformSaveFilePrompt().save(
        suggestedName: 'marklens-log',
        extension: 'txt',
        bytes: Uint8List(0),
      );

      expect(shown, written.toFilePath());
    });

    test('any other URI comes back as itself', () async {
      platform.saved = Uri.parse('content://downloads/public/7');

      final shown = await const PlatformSaveFilePrompt().save(
        suggestedName: 'marklens-log',
        extension: 'txt',
        bytes: Uint8List(0),
      );

      expect(shown, 'content://downloads/public/7');
    });

    test('a cancelled dialog is null', () async {
      final shown = await const PlatformSaveFilePrompt().save(
        suggestedName: 'marklens-log',
        extension: 'txt',
        bytes: Uint8List(0),
      );

      expect(shown, isNull);
    });
  });
}
