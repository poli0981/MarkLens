import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the reader where to put a file, and hands the platform the bytes.
///
/// A seam over `file_picker`'s save dialog, for the same reasons
/// `FilePickerPrompt` in `app/open_files.dart` is one: a platform channel does
/// not exist in a widget test, and those two files are the only places in the
/// app that touch the plugin.
///
/// **`file_picker` 12 does the writing.** `saveFile` takes the bytes and
/// returns the `Uri` of what it wrote; there is no "just give me a path"
/// variant. Doc 01 already records that this package changed shape at 12, and
/// this is the second half of that change. The consequence is worth stating
/// plainly: MarkLens's own code now performs **no** file write outside its
/// config directory at all — see `docs/10_SECURITY_PRIVACY.md` invariant 5.
abstract class SaveFilePrompt {
  /// Writes [bytes] wherever the reader chooses.
  ///
  /// Returns the path written, or `null` when the dialog was cancelled or the
  /// platform refused.
  Future<String?> save({
    required String suggestedName,
    required String extension,
    required Uint8List bytes,
  });
}

/// The real dialog.
class PlatformSaveFilePrompt implements SaveFilePrompt {
  /// Creates a prompt.
  const PlatformSaveFilePrompt();

  @override
  Future<String?> save({
    required String suggestedName,
    required String extension,
    required Uint8List bytes,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: '$suggestedName.$extension',
      bytes: bytes,
      mimeType: 'text/plain',
      type: FileType.custom,
      allowedExtensions: <String>[extension],
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    if (saved == null) {
      return null;
    }
    // On desktop the scheme is `file`; `toFilePath` is what turns that back
    // into something worth showing a person.
    return saved.isScheme('file') ? saved.toFilePath() : saved.toString();
  }
}

/// What a widget test gets: records the bytes, writes nothing.
class StubSaveFilePrompt implements SaveFilePrompt {
  /// Creates a stub that answers with [destination].
  StubSaveFilePrompt([this.destination]);

  /// The path the dialog "chose", or `null` for a cancelled dialog.
  String? destination;

  /// How many times it was opened.
  int calls = 0;

  /// What it was last asked to write.
  Uint8List? written;

  @override
  Future<String?> save({
    required String suggestedName,
    required String extension,
    required Uint8List bytes,
  }) async {
    calls++;
    written = bytes;
    return destination;
  }
}

/// The save-dialog provider.
final Provider<SaveFilePrompt> saveFilePromptProvider =
    Provider<SaveFilePrompt>((ref) => const PlatformSaveFilePrompt());
