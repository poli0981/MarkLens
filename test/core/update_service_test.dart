import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/log/log_buffer.dart';
import 'package:marklens/core/update/semver.dart';
import 'package:marklens/core/update/update_service.dart';

/// `docs/11_PACKAGING_UPDATE.md`: strip `v`, compare SemVer, newer → banner.
/// Failures silent, logged to the ring buffer.
///
/// The transport is a stub throughout. The real one opens a socket, and a unit
/// test that reached the internet would be testing GitHub's uptime.
class _StubTransport implements UpdateTransport {
  _StubTransport(this.body);

  String? body;
  final List<Uri> asked = <Uri>[];

  @override
  Future<String?> fetchLatestRelease(Uri endpoint) async {
    asked.add(endpoint);
    return body;
  }
}

String release(String tag, {bool draft = false, bool prerelease = false}) =>
    '{"tag_name":"$tag","html_url":"https://example.com/r/$tag",'
    '"draft":$draft,"prerelease":$prerelease}';

void main() {
  group('SemVer', () {
    SemVer parse(String value) => SemVer.tryParse(value)!;

    test('strips the v the tags are written with', () {
      expect(parse('v1.2.3').toString(), '1.2.3');
      expect(parse('1.2.3').toString(), '1.2.3');
      expect(parse('V1.2.3').toString(), '1.2.3');
    });

    test('drops build metadata, which takes no part in precedence', () {
      expect(parse('0.1.0+7').compareTo(parse('0.1.0+8')), 0);
    });

    test('orders by major, then minor, then patch', () {
      expect(parse('2.0.0').isNewerThan(parse('1.9.9')), isTrue);
      expect(parse('1.10.0').isNewerThan(parse('1.9.0')), isTrue);
      expect(parse('1.0.10').isNewerThan(parse('1.0.9')), isTrue);
      expect(parse('1.0.0').isNewerThan(parse('1.0.0')), isFalse);
    });

    test('a prerelease is older than its release, not newer', () {
      // The one that would be embarrassing: telling someone on 1.0.0 that
      // 1.0.0-rc.1 is an upgrade.
      expect(parse('1.0.0-rc.1').isNewerThan(parse('1.0.0')), isFalse);
      expect(parse('1.0.0').isNewerThan(parse('1.0.0-rc.1')), isTrue);
    });

    test('and two prereleases order by identifier', () {
      expect(parse('1.0.0-rc.2').isNewerThan(parse('1.0.0-rc.1')), isTrue);
      expect(parse('1.0.0-rc.10').isNewerThan(parse('1.0.0-rc.9')), isTrue);
      expect(parse('1.0.0-beta').isNewerThan(parse('1.0.0-alpha')), isTrue);
      expect(parse('1.0.0-rc').isNewerThan(parse('1.0.0-1')), isTrue);
    });

    test('nonsense is null rather than an exception', () {
      for (final value in <String>[
        '',
        'v',
        '1',
        '1.2',
        '1.2.3.4',
        'one.two.three',
        '-1.0.0',
        'v1.2.x',
        '1.0.0-',
      ]) {
        expect(SemVer.tryParse(value), isNull, reason: 'parsed "$value"');
      }
    });
  });

  group('the check', () {
    final current = SemVer.tryParse('1.0.0')!;

    test('reports a newer release, with its page', () async {
      final transport = _StubTransport(release('v1.2.0'));

      final found = await UpdateService(transport: transport).check(
        current: current,
      );

      expect(found?.version.toString(), '1.2.0');
      expect(found?.page.toString(), 'https://example.com/r/v1.2.0');
    });

    test('says nothing when up to date', () async {
      final transport = _StubTransport(release('v1.0.0'));

      expect(
        await UpdateService(transport: transport).check(current: current),
        isNull,
      );
    });

    test('and nothing when the release is older', () async {
      final transport = _StubTransport(release('v0.9.0'));

      expect(
        await UpdateService(transport: transport).check(current: current),
        isNull,
      );
    });

    test('a draft is not a release', () async {
      final transport = _StubTransport(release('v2.0.0', draft: true));

      expect(
        await UpdateService(transport: transport).check(current: current),
        isNull,
      );
    });

    test('and neither is a prerelease', () async {
      final transport = _StubTransport(release('v2.0.0', prerelease: true));

      expect(
        await UpdateService(transport: transport).check(current: current),
        isNull,
      );
    });

    test('it asks the endpoint doc 11 names, over https', () async {
      final transport = _StubTransport(release('v1.0.0'));

      await UpdateService(transport: transport).check(current: current);

      expect(transport.asked.single.scheme, 'https');
      expect(transport.asked.single.host, 'api.github.com');
      expect(
        transport.asked.single.path,
        '/repos/poli0981/MarkLens/releases/latest',
      );
    });
  });

  group('failure is silent, and logged', () {
    final current = SemVer.tryParse('1.0.0')!;

    test('offline says nothing and writes a warning', () async {
      final log = LogBuffer();
      final transport = _StubTransport(null);

      final found = await UpdateService(
        transport: transport,
      ).check(current: current, log: log);

      expect(found, isNull);
      expect(log.length, 1);
      expect(log.entries.single.level, LogLevel.warning);
      expect(log.entries.single.source, 'update');
    });

    test('a response that is not JSON is a warning, not a crash', () async {
      final log = LogBuffer();

      for (final body in <String>[
        '',
        'not json',
        '[]',
        '{}',
        '{"tag_name":42}',
        '{"tag_name":"not-a-version"}',
        '{"tag_name":"v1.2.0"',
      ]) {
        final found = await UpdateService(
          transport: _StubTransport(body),
        ).check(current: current, log: log);
        expect(found, isNull, reason: 'body was "$body"');
      }
      expect(log.entries.every((e) => e.level == LogLevel.warning), isTrue);
    });

    test(
      'a release with no html_url still reaches the releases page',
      () async {
        final transport = _StubTransport('{"tag_name":"v2.0.0"}');

        final found = await UpdateService(transport: transport).check(
          current: current,
        );

        expect(found, isNotNull);
        expect(found!.page.host, 'github.com');
      },
    );

    test('up to date is logged at info, because nothing went wrong', () async {
      final log = LogBuffer();

      await UpdateService(
        transport: _StubTransport(release('v1.0.0')),
      ).check(current: current, log: log);

      expect(log.entries.single.level, LogLevel.info);
    });
  });

  group('the 24-hour interval', () {
    final service = UpdateService(transport: _StubTransport(null));
    final now = DateTime.utc(2026, 8, 28, 12);

    test('never checked is due', () {
      expect(service.isDue(null, now: now), isTrue);
    });

    test('checked just now is not', () {
      expect(
        service.isDue(now.subtract(const Duration(hours: 1)), now: now),
        isFalse,
      );
      expect(
        service.isDue(
          now.subtract(const Duration(hours: 23, minutes: 59)),
          now: now,
        ),
        isFalse,
      );
    });

    test('checked a day ago is', () {
      expect(
        service.isDue(now.subtract(const Duration(hours: 24)), now: now),
        isTrue,
      );
      expect(
        service.isDue(now.subtract(const Duration(days: 8)), now: now),
        isTrue,
      );
    });
  });
}
