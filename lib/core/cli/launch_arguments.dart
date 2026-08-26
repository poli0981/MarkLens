import 'package:args/args.dart';

/// What the command line asked for.
typedef LaunchArguments = ({
  /// Files and folders named on the command line, in the order given.
  List<String> paths,

  /// Whether `--help` was asked for.
  bool help,

  /// Whether `--version` was asked for.
  bool version,

  /// A message explaining why the arguments could not be used, or `null`.
  String? error,
});

/// Parses MarkLens's command line.
///
/// Deliberately tiny. MarkLens opens documents; it is not a tool with modes,
/// and a viewer that grows flags grows a manual. Everything positional is a
/// path, and the extension registry decides later whether a path is one
/// MarkLens renders — a file named explicitly opens even if a folder scan
/// would have skipped it, because user intent wins (`docs/07_FILES_AND_WATCH`).
///
/// Never throws. A malformed command line comes back as an `error` field
/// so the launcher can print it and carry on, rather than dying before the
/// window exists (CLAUDE.md rule 9).
LaunchArguments parseLaunchArguments(List<String> argv) {
  final parser = _parser();
  try {
    final results = parser.parse(argv);
    return (
      paths: List<String>.unmodifiable(results.rest),
      help: results.flag('help'),
      version: results.flag('version'),
      error: null,
    );
  } on FormatException catch (failure) {
    return (
      paths: const <String>[],
      help: false,
      version: false,
      error: failure.message,
    );
  }
}

/// The `--help` text.
String launchUsage() =>
    'MarkLens — a read-only Markdown viewer.\n'
    '\n'
    'Usage: marklens [options] [files or folders...]\n'
    '\n'
    '${_parser().usage}';

ArgParser _parser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this message.')
  ..addFlag(
    'version',
    abbr: 'v',
    negatable: false,
    help: 'Print the version and exit.',
  );
