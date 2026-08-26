import 'package:file_picker/file_picker.dart';
import 'package:marklens/core/files/extension_registry.dart';

/// Asks the user for documents to open.
///
/// A thin seam over `file_picker` so the shell can be pumped in a widget test
/// without a platform dialog: tests hand [FilePickerPrompt] a stub, and
/// nothing else in the app touches the plugin.
abstract class FilePickerPrompt {
  /// The paths chosen, or an empty list when the dialog was cancelled.
  Future<List<String>> pickDocuments(ExtensionRegistry registry);

  /// The folder chosen, or `null` when the dialog was cancelled.
  Future<String?> pickFolder();
}

/// The real dialog.
class PlatformFilePickerPrompt implements FilePickerPrompt {
  /// Creates a prompt.
  const PlatformFilePickerPrompt();

  @override
  Future<List<String>> pickDocuments(ExtensionRegistry registry) async {
    // file_picker 12 moved this: it is a static returning the list directly,
    // where 11 and earlier went through `FilePicker.platform` and returned a
    // nullable result object. Doc 01 flagged the major bump; this is what it
    // meant.
    final files = await FilePicker.pickFiles(
      // The registry gates the dialog filter exactly as it gates a folder
      // scan — one answer to "is this ours" (`docs/07_FILES_AND_WATCH.md`).
      type: FileType.custom,
      allowedExtensions: registry.extensions,
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );
    // A cancelled dialog is an empty list, not a null.
    return <String>[for (final file in files) ?file.path];
  }

  @override
  Future<String?> pickFolder() => FilePicker.getDirectoryPath(
    windowsOptions: const WindowsOptions(lockParentWindow: true),
    linuxOptions: const LinuxOptions(lockParentWindow: true),
  );
}
