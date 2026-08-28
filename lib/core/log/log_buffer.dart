/// The in-memory diagnostic log (`docs/02_ARCHITECTURE.md`, "Logging").
///
/// A ring buffer of 500 plain structs. **Nothing is written to disk**: doc 02
/// is explicit that there are no log files, and doc 10's privacy posture rests
/// on it — the only way an entry leaves this process is Help → Export
/// Diagnostic Log, which the reader points at a file themselves.
///
/// Pure Dart, so the services that log are testable without a binding.
library;

/// How serious an entry is.
///
/// Three levels, not five. A viewer has one kind of problem worth a level —
/// "something did not work and you may want to know why" — and the other two
/// exist to separate it from the ordinary trace around it.
enum LogLevel {
  /// Ordinary activity: a file opened, a check ran.
  info,

  /// Something degraded but carried on — a parse fell back, a watcher failed
  /// to start. Rule 9 in the log.
  warning,

  /// Something failed outright.
  error,
}

/// One line of the log.
class LogEntry {
  /// Creates an entry.
  const LogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
  });

  /// When it happened, in UTC.
  ///
  /// UTC because an exported log may be read in another timezone, and a
  /// timestamp that silently means "wherever the writer was" is worse than no
  /// timestamp.
  final DateTime time;

  /// How serious it is.
  final LogLevel level;

  /// Which part of the app said it — `update`, `watch`, `pipeline`.
  final String source;

  /// What happened.
  ///
  /// **May contain file paths**, which doc 10 says plainly: paths the user
  /// themselves opened are the one piece of personal information here, they
  /// stay in RAM, and they leave only by explicit export. Nothing else about
  /// the user is ever put in one.
  final String message;

  /// One line of the exported file.
  ///
  /// Deliberately not JSON: the thing a person does with a diagnostic log is
  /// read it, or paste it into an issue.
  @override
  String toString() =>
      '${time.toIso8601String()}  ${level.name.padRight(7)}  '
      '${source.padRight(10)}  $message';
}

/// A bounded, in-memory log.
class LogBuffer {
  /// Creates a buffer holding at most [capacity] entries.
  LogBuffer({this.capacity = defaultCapacity})
    : assert(capacity > 0, 'a log that holds nothing is not a log');

  /// Doc 02's figure.
  static const int defaultCapacity = 500;

  /// How many entries are kept before the oldest is dropped.
  final int capacity;

  final List<LogEntry> _entries = <LogEntry>[];

  /// Every entry held, oldest first.
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  /// How many entries are held.
  int get length => _entries.length;

  /// Records [message] from [source].
  ///
  /// [now] is injectable because a log with a real clock in it is a log that
  /// cannot be asserted on.
  void add(
    String source,
    String message, {
    LogLevel level = LogLevel.info,
    DateTime? now,
  }) {
    _entries.add(
      LogEntry(
        time: (now ?? DateTime.now()).toUtc(),
        level: level,
        source: source,
        message: message,
      ),
    );
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
  }

  /// Records a degradation — something carried on without working.
  void warn(String source, String message, {DateTime? now}) =>
      add(source, message, level: LogLevel.warning, now: now);

  /// Records a failure.
  void error(String source, String message, {DateTime? now}) =>
      add(source, message, level: LogLevel.error, now: now);

  /// Forgets everything.
  void clear() => _entries.clear();

  /// The whole log as text, for the export.
  String render() => _entries.map((entry) => entry.toString()).join('\n');
}
