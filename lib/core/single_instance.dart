import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// What happened when a launch tried to become the running instance.
enum InstanceRole {
  /// This process is the one instance. It is listening for later launches.
  primary,

  /// Another instance was already running; its arguments were handed over and
  /// this process should exit quietly.
  handedOver,

  /// Single-instance handling could not be set up. The launch continues as an
  /// ordinary window rather than failing — a second window is a much smaller
  /// problem than no window (CLAUDE.md rule 9).
  standalone,
}

/// Makes a second launch hand its arguments to the first.
///
/// Opening `README.md` from Explorer while MarkLens is already running should
/// add a tab, not start a second copy with its own session — two processes
/// writing one `session.json` is how a session gets lost.
///
/// **This is the one socket in MarkLens, and it is not network egress.** It
/// binds `127.0.0.1` on an ephemeral port and writes that port into a lock file
/// beside the config, so nothing is reachable from another machine and no fixed
/// port can collide with unrelated software. `test/architecture/no_network_test`
/// names this file explicitly rather than widening its forbidden-token list,
/// which is the deliberate handling that test asked for.
///
/// What crosses the socket is a list of paths and nothing else. They are
/// treated exactly like paths typed on the command line — described by
/// `FileService`, opened if they are files, ignored if they are not. Nothing
/// received here is ever executed (CLAUDE.md rule 2).
class SingleInstance {
  /// Creates a coordinator storing its lock in [directory].
  SingleInstance({
    required this.directory,
    this.connectTimeout = const Duration(seconds: 2),
  });

  /// The app's config directory, injected like the stores' (rule 3).
  final Directory directory;

  /// How long a handover waits before deciding the lock is stale.
  final Duration connectTimeout;

  ServerSocket? _server;
  final StreamController<List<String>> _forwarded =
      StreamController<List<String>>.broadcast();

  /// The lock file recording which port the running instance listens on.
  File get lockFile =>
      File('${directory.path}${Platform.pathSeparator}instance.lock');

  /// Paths handed over by later launches.
  Stream<List<String>> get forwardedPaths => _forwarded.stream;

  /// Whether this process is listening.
  bool get isPrimary => _server != null;

  /// Tries to become the running instance, forwarding [paths] if one exists.
  Future<InstanceRole> acquire(List<String> paths) async {
    // Ask first. A lock file with a live listener behind it is the common
    // case, and trying to bind before asking would race two launches into
    // both believing they are primary.
    if (await _handOver(paths)) {
      return InstanceRole.handedOver;
    }

    try {
      // Loopback only, and an ephemeral port so nothing can collide.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(_receive, onError: (Object _) {});
      _writeLock(server.port);
      return InstanceRole.primary;
    } on SocketException {
      // No socket, no forwarding — but still a usable window.
      return InstanceRole.standalone;
    } on FileSystemException {
      return InstanceRole.standalone;
    }
  }

  /// Stops listening and removes the lock.
  ///
  /// Idempotent, and safe to call twice *at once*: the exit sequence can be
  /// entered from a second close while the first is still running, and two
  /// concurrent releases would otherwise both find the server and close it
  /// twice. The first call owns the work; every later one joins it.
  Future<void> release() => _released ??= _releaseOnce();

  Future<void>? _released;

  Future<void> _releaseOnce() async {
    final server = _server;
    _server = null;
    await server?.close();
    await _forwarded.close();
    _removeLock();
  }

  /// Sends [paths] to a running instance, if there is one.
  Future<bool> _handOver(List<String> paths) async {
    final port = _readLockPort();
    if (port == null) {
      return false;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
      ).timeout(connectTimeout);
      // One line, so the receiver knows when the payload is complete without
      // waiting for the socket to close.
      await (socket..write('${jsonEncode(paths)}\n')).flush();
      return true;
    } on Object {
      // A lock left behind by a crash, or a port now owned by something else.
      // Either way there is nobody to hand over to, and this launch becomes
      // the primary.
      return false;
    } finally {
      await socket?.close();
    }
  }

  void _receive(Socket client) {
    // Bounded: a payload that never ends, or is not a JSON list of strings, is
    // dropped rather than trusted. This is the only input MarkLens takes from
    // outside a file, so it is the only place worth being paranoid.
    var received = 0;
    final buffer = StringBuffer();
    client.listen(
      (chunk) {
        received += chunk.length;
        if (received > _maxPayloadBytes) {
          unawaited(client.close());
          return;
        }
        buffer.write(utf8.decode(chunk, allowMalformed: true));
      },
      onDone: () {
        _emit(buffer.toString());
        unawaited(client.close());
      },
      onError: (Object _) => unawaited(client.close()),
      cancelOnError: true,
    );
  }

  void _emit(String payload) {
    try {
      final decoded = jsonDecode(payload.trim());
      if (decoded is! List) {
        return;
      }
      final paths = <String>[
        for (final entry in decoded)
          if (entry is String && entry.trim().isNotEmpty) entry,
      ];
      if (paths.isNotEmpty && !_forwarded.isClosed) {
        _forwarded.add(paths);
      }
    } on FormatException {
      // Not ours. Ignore it.
    }
  }

  int? _readLockPort() {
    try {
      if (!lockFile.existsSync()) {
        return null;
      }
      return int.tryParse(lockFile.readAsStringSync().trim());
    } on FileSystemException {
      return null;
    }
  }

  void _writeLock(int port) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    lockFile.writeAsStringSync('$port', flush: true);
  }

  void _removeLock() {
    try {
      if (lockFile.existsSync()) {
        lockFile.deleteSync();
      }
    } on FileSystemException {
      // A lock that outlives the process is handled on the next launch: the
      // connect fails and that launch becomes primary.
    }
  }

  /// Far more than any command line, far less than anything worth buffering.
  static const int _maxPayloadBytes = 64 * 1024;
}
