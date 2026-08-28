import 'dart:convert';
import 'dart:typed_data';

import 'package:marklens/app/providers.dart';
import 'package:marklens/core/log/log_buffer.dart';

/// How the diagnostic-log export went.
enum LogExportOutcome {
  /// Written where the reader pointed.
  written,

  /// The dialog was cancelled, or the platform refused.
  cancelled,
}

/// Help → Export Diagnostic Log (`docs/02_ARCHITECTURE.md`, "Logging").
///
/// The log is a ring buffer in memory and there are no log files on disk; this
/// is the only way an entry ever leaves the process, and it takes an explicit
/// action every time (`docs/10_SECURITY_PRIVACY.md`).
///
/// **It does not write the file itself.** `file_picker` 12's `saveFile` takes
/// the bytes and writes them where the reader chose, so what happens here is
/// encoding and nothing else. That is why `lib/features/about/` no longer
/// appears in `no_write_test`'s allowlist: MarkLens's own code performs no
/// write outside its config directory at all.
class LogExporter {
  /// Creates an exporter.
  const LogExporter({this.suggestedName = 'marklens-log'});

  /// The filename offered by the dialog, without its extension.
  final String suggestedName;

  /// The extension the exported log takes.
  static const String extension = 'log';

  /// Offers [buffer] to the reader, and reports where it went.
  Future<({LogExportOutcome outcome, String? path})> export({
    required SaveFilePrompt prompt,
    required LogBuffer buffer,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode('${buffer.render()}\n'));
    final path = await prompt.save(
      suggestedName: suggestedName,
      extension: extension,
      bytes: bytes,
    );
    return path == null
        ? (outcome: LogExportOutcome.cancelled, path: null)
        : (outcome: LogExportOutcome.written, path: path);
  }
}
