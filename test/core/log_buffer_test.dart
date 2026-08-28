import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/log/log_buffer.dart';

/// `docs/02_ARCHITECTURE.md`, "Logging": an in-memory ring buffer of 500
/// entries, no log files on disk, exported only by explicit user action.
void main() {
  final at = DateTime.utc(2026, 8, 28, 9, 30);

  group('the ring', () {
    test('keeps entries in order', () {
      final log = LogBuffer()
        ..add('a', 'first', now: at)
        ..add('b', 'second', now: at);

      expect(log.entries.map((e) => e.message), <String>['first', 'second']);
    });

    test('drops the oldest past its capacity, and only the oldest', () {
      final log = LogBuffer(capacity: 3);
      for (var i = 0; i < 10; i++) {
        log.add('src', 'entry $i', now: at);
      }

      expect(log.length, 3);
      expect(
        log.entries.map((e) => e.message),
        <String>['entry 7', 'entry 8', 'entry 9'],
      );
    });

    test('doc 02 says five hundred', () {
      expect(LogBuffer.defaultCapacity, 500);
      expect(LogBuffer().capacity, 500);
    });

    test('a thousand entries cost five hundred, not a thousand', () {
      final log = LogBuffer();
      for (var i = 0; i < 5000; i++) {
        log.add('src', 'entry $i', now: at);
      }

      expect(log.length, 500);
    });

    test('clearing empties it', () {
      final log = LogBuffer()
        ..add('a', 'x', now: at)
        ..clear();

      expect(log.entries, isEmpty);
    });
  });

  group('levels', () {
    test('three, and the helpers set them', () {
      final log = LogBuffer()
        ..add('a', 'ordinary', now: at)
        ..warn('a', 'degraded', now: at)
        ..error('a', 'failed', now: at);

      expect(
        log.entries.map((e) => e.level),
        <LogLevel>[LogLevel.info, LogLevel.warning, LogLevel.error],
      );
    });
  });

  group('what an exported line looks like', () {
    test('timestamp, level, source, message — and it is readable', () {
      // Deliberately not JSON: what a person does with a diagnostic log is
      // read it, or paste it into an issue.
      final log = LogBuffer()..warn('update', 'no answer', now: at);

      final line = log.render();

      expect(line, startsWith('2026-08-28T09:30:00.000Z'));
      expect(line, contains('warning'));
      expect(line, contains('update'));
      expect(line, endsWith('no answer'));
    });

    test('times are UTC, whatever the writer’s clock said', () {
      // An exported log may be read in another timezone, and a timestamp that
      // silently means "wherever the writer was" is worse than none.
      final log = LogBuffer()..add('a', 'x', now: DateTime.utc(2026).toLocal());

      expect(log.entries.single.time.isUtc, isTrue);
    });

    test('an empty log renders to nothing rather than failing', () {
      expect(LogBuffer().render(), isEmpty);
    });

    test('one line per entry', () {
      final log = LogBuffer()
        ..add('a', 'one', now: at)
        ..add('a', 'two', now: at);

      expect(log.render().split('\n'), hasLength(2));
    });
  });
}
