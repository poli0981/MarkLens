/// `docs/02_ARCHITECTURE.md` and `docs/03_DATA_FLOW.md`: a second launch hands
/// its arguments to the first rather than starting a rival window.
///
/// This is the only socket in MarkLens, so the last group is the one that
/// earns it its named exception in `test/architecture/no_network_test.dart`:
/// it binds loopback, and it writes nothing outside the directory it was
/// handed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/single_instance.dart';

void main() {
  late Directory root;
  late Directory config;
  final instances = <SingleInstance>[];

  SingleInstance instanceIn(Directory directory) {
    final instance = SingleInstance(
      directory: directory,
      connectTimeout: const Duration(milliseconds: 300),
    );
    instances.add(instance);
    return instance;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('marklens_instance_');
    config = Directory('${root.path}${Platform.pathSeparator}config');
    instances.clear();
  });

  tearDown(() async {
    for (final instance in instances) {
      await instance.release();
    }
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('acquiring', () {
    test('the first launch becomes the primary and writes a lock', () async {
      final first = instanceIn(config);

      expect(await first.acquire(const <String>[]), InstanceRole.primary);
      expect(first.isPrimary, isTrue);
      expect(first.lockFile.existsSync(), isTrue);
      expect(int.tryParse(first.lockFile.readAsStringSync()), isNotNull);
    });

    test('a second launch hands over instead of binding', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      final handed = first.forwardedPaths.first;
      final second = instanceIn(config);

      expect(
        await second.acquire(<String>['/docs/README.md']),
        InstanceRole.handedOver,
      );
      expect(second.isPrimary, isFalse);
      expect(await handed, <String>['/docs/README.md']);
    });

    test('several paths arrive in order', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);
      final handed = first.forwardedPaths.first;

      await instanceIn(config).acquire(<String>['/a.md', '/b.md', '/c.md']);

      expect(await handed, <String>['/a.md', '/b.md', '/c.md']);
    });

    test('a stale lock is taken over rather than obeyed', () async {
      config.createSync(recursive: true);
      // A port nothing is listening on: what a crash leaves behind.
      File(
        '${config.path}${Platform.pathSeparator}instance.lock',
      ).writeAsStringSync('1');

      final instance = instanceIn(config);
      expect(
        await instance.acquire(const <String>[]),
        InstanceRole.primary,
        reason:
            'a lock left by a crash must not lock the user out of their own '
            'application',
      );
    });

    test('an unreadable lock is treated as no lock', () async {
      config.createSync(recursive: true);
      File(
        '${config.path}${Platform.pathSeparator}instance.lock',
      ).writeAsStringSync('not a port');

      expect(
        await instanceIn(config).acquire(const <String>[]),
        InstanceRole.primary,
      );
    });

    test('releasing removes the lock, so the next launch is primary', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);
      await first.release();

      expect(first.lockFile.existsSync(), isFalse);
      expect(
        await instanceIn(config).acquire(const <String>[]),
        InstanceRole.primary,
      );
    });

    test('releasing twice, and twice at once, is harmless', () async {
      // The exit sequence can be entered from a second close while the first
      // is still running (`docs/03_DATA_FLOW.md`, "App exit").
      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      await Future.wait(<Future<void>>[first.release(), first.release()]);
      await first.release();

      expect(first.isPrimary, isFalse);
      expect(first.lockFile.existsSync(), isFalse);
      expect(
        await instanceIn(config).acquire(const <String>[]),
        InstanceRole.primary,
      );
    });

    test('releasing an instance that never acquired is harmless', () async {
      await expectLater(instanceIn(config).release(), completes);
    });
  });

  group('what crosses the socket is only paths', () {
    test('a payload that is not a JSON list is dropped', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      var received = 0;
      first.forwardedPaths.listen((_) => received++);

      final port = int.parse(first.lockFile.readAsStringSync());
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
      );
      socket.write('{"run": "something"}\n');
      await socket.flush();
      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        received,
        0,
        reason:
            'the only thing this socket accepts is a list of paths; anything '
            'else is ignored rather than interpreted',
      );
    });

    test('non-string entries are filtered out', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);
      final handed = first.forwardedPaths.first;

      final port = int.parse(first.lockFile.readAsStringSync());
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write(
        '${jsonEncode(<Object?>['/a.md', 42, null, '', '/b.md'])}\n',
      );
      await socket.flush();
      await socket.close();

      expect(await handed, <String>['/a.md', '/b.md']);
    });

    test('an oversized payload is dropped rather than buffered', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      var received = 0;
      first.forwardedPaths.listen((_) => received++);

      final port = int.parse(first.lockFile.readAsStringSync());
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      socket.write('["${'a' * (128 * 1024)}"]\n');
      await socket.flush();
      await socket.close();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(received, 0);
    });
  });

  group('it stays where it was put', () {
    test('binds loopback, not a network interface', () async {
      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      final port = int.parse(first.lockFile.readAsStringSync());
      expect(port, greaterThan(0));
      // Reachable on loopback...
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      await socket.close();
      // ...and that is the only address it was given.
      expect(
        File('lib/core/single_instance.dart').readAsStringSync(),
        contains('InternetAddress.loopbackIPv4'),
      );
    });

    test('writes nothing outside the directory it was handed', () async {
      final sibling = Directory('${root.path}${Platform.pathSeparator}other')
        ..createSync();

      final first = instanceIn(config);
      await first.acquire(const <String>[]);

      expect(sibling.listSync(), isEmpty);
      expect(
        config.listSync().map(
          (e) => e.path.split(RegExp(r'[/\\]')).last,
        ),
        <String>['instance.lock'],
      );
    });

    test('two config directories are two independent instances', () async {
      final other = Directory('${root.path}${Platform.pathSeparator}other');

      expect(
        await instanceIn(config).acquire(const <String>[]),
        InstanceRole.primary,
      );
      expect(
        await instanceIn(other).acquire(const <String>[]),
        InstanceRole.primary,
        reason: 'the lock is per config directory, not per machine',
      );
    });
  });
}
