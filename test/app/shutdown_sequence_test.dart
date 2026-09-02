/// `ShutdownSequence` on its own (`docs/03_DATA_FLOW.md`, "App exit"): the
/// order, the bounds, and that it runs once.
///
/// No widgets: what the shell wires into it is `test/app/shutdown_test.dart`'s
/// business. Here every collaborator is a recorder, so the assertions are
/// about *sequence*, which is the whole point of the class.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/app/shutdown.dart';
import 'package:marklens/app/watch_link.dart';
import 'package:marklens/app/window_link.dart';
import 'package:marklens/core/log/log_buffer.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/models/watch_event.dart';
import 'package:marklens/core/single_instance.dart';
import 'package:window_manager/window_manager.dart';

class _RecordingWatchLink implements WatchLink {
  _RecordingWatchLink(this.order, {this.hang = false});

  final List<String> order;

  /// Whether `dispose` never completes — a watcher that does not answer.
  final bool hang;

  int disposed = 0;

  @override
  Stream<WatchEvent> get events => const Stream<WatchEvent>.empty();

  @override
  void sync({
    required Iterable<String> roots,
    required Iterable<String> files,
  }) {}

  @override
  void flush() {}

  @override
  bool get degraded => false;

  @override
  Future<void> dispose() {
    disposed++;
    order.add('watch.dispose');
    return hang ? Completer<void>().future : Future<void>.value();
  }
}

class _RecordingWindowLink implements WindowLink {
  _RecordingWindowLink(this.order);

  final List<String> order;
  int closed = 0;
  WindowListener? detached;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> restore(WindowGeometry? geometry) async {}

  @override
  Future<WindowGeometry?> current() async => null;

  @override
  Future<void> attach(WindowListener listener) async {}

  @override
  Future<void> detachAndClose(WindowListener listener) async {
    closed++;
    detached = listener;
    order.add('window.detachAndClose');
  }

  @override
  Future<void> focus() async {}

  @override
  Future<void> setFullScreen({required bool full}) async {}

  @override
  Future<void> requestClose() async {}
}

class _RecordingInstance extends SingleInstance {
  _RecordingInstance(this.order, {required super.directory});

  final List<String> order;
  int released = 0;

  @override
  Future<void> release() {
    released++;
    order.add('instance.release');
    return super.release();
  }
}

class _Listener with WindowListener {}

void main() {
  late Directory config;
  late List<String> order;
  late LogBuffer log;
  late _RecordingWatchLink watch;
  late _RecordingWindowLink window;
  late _RecordingInstance instance;

  setUp(() {
    config = Directory.systemTemp.createTempSync('marklens_shutdown_');
    order = <String>[];
    log = LogBuffer();
    watch = _RecordingWatchLink(order);
    window = _RecordingWindowLink(order);
    instance = _RecordingInstance(order, directory: config);
  });

  tearDown(() {
    if (config.existsSync()) {
      config.deleteSync(recursive: true);
    }
  });

  ShutdownSequence sequence({
    Future<void> Function()? recordGeometry,
    Duration watchTimeout = const Duration(seconds: 1),
    _RecordingWatchLink? watchLink,
  }) => ShutdownSequence(
    recordGeometry: recordGeometry ?? () async => order.add('geometry'),
    flushSettings: () => order.add('settings'),
    flushSession: () => order.add('session'),
    stopListening: () => order.add('listeners'),
    watch: watchLink ?? watch,
    instance: instance,
    window: window,
    listener: _Listener(),
    log: log,
    watchTimeout: watchTimeout,
  );

  test('writes first, asks the watchers next, and leaves last', () async {
    await sequence().run();

    expect(order, <String>[
      'geometry',
      'settings',
      'session',
      'listeners',
      'watch.dispose',
      'instance.release',
      'window.detachAndClose',
    ]);
    expect(log.entries, isEmpty, reason: 'nothing to warn about');
  });

  test('runs once: a second close joins the first', () async {
    final exit = sequence();
    final first = exit.run();
    final second = exit.run();

    expect(identical(first, second), isTrue);
    await first;
    expect(exit.started, isTrue);
    expect(watch.disposed, 1);
    expect(instance.released, 1);
    expect(window.closed, 1);
    expect(order.where((step) => step == 'settings'), hasLength(1));
  });

  test('a watcher that never answers does not hold the exit', () async {
    final stuck = _RecordingWatchLink(order, hang: true);
    await sequence(
      watchLink: stuck,
      watchTimeout: const Duration(milliseconds: 20),
    ).run().timeout(const Duration(seconds: 2));

    expect(window.closed, 1);
    expect(order.last, 'window.detachAndClose');
    final warning = log.entries.singleWhere(
      (entry) => entry.level == LogLevel.warning,
    );
    expect(warning.source, ShutdownSequence.logSource);
    expect(warning.message, contains('watchers'));
    expect(warning.message, contains('20 ms'));
  });

  test('a geometry query that fails still writes and still leaves', () async {
    await sequence(
      recordGeometry: () async => throw StateError('no window'),
    ).run();

    expect(order, containsAllInOrder(<String>['settings', 'session']));
    expect(window.closed, 1);
    expect(
      log.entries.single.message,
      allOf(contains('window geometry'), contains('no window')),
    );
  });

  test('the listener it detaches is the one it was given', () async {
    final listener = _Listener();
    await ShutdownSequence(
      recordGeometry: () async {},
      flushSettings: () {},
      flushSession: () {},
      stopListening: () {},
      watch: watch,
      instance: instance,
      window: window,
      listener: listener,
      log: log,
    ).run();

    expect(identical(window.detached, listener), isTrue);
  });
}
