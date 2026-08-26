import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// CLAUDE.md rule 5 / `docs/10_SECURITY_PRIVACY.md` invariant 4: zero network
/// by default. Exactly two call sites may exist — the GitHub Releases update
/// check, and remote image loading (setting-controlled, off by default).
///
/// This matters concretely rather than theoretically: `flutter_svg` pulls
/// `http` in transitively (docs/01_TECH_STACK.md), so a network-capable API is
/// sitting in the binary one autocomplete away from being used by accident.
const List<String> networkApis = <String>[
  'HttpClient',
  'HttpOverrides',
  'package:http/',
  'Socket.connect',
  'SecureSocket.connect',
  'RawSocket.connect',
  'Image.network',
  'NetworkImage',
  'SvgPicture.network',
  'WebSocket',
];

/// The only two directories allowed to touch the network.
const List<String> networkAllowedPrefixes = <String>[
  // Update check: HTTPS GET to api.github.com, at most daily (docs/11).
  'lib/core/update/',
  // Remote images: off by default, host chosen by the document (docs/04).
  'lib/features/reader/images/',
  // The single-instance arg forwarder. Not network egress: it binds 127.0.0.1
  // on an ephemeral port and hands a list of paths to the already-running
  // window (docs/02_ARCHITECTURE.md, docs/03_DATA_FLOW.md). Named here rather
  // than handled by widening the token list, which is what the guard test
  // below asked for.
  'lib/core/single_instance.dart',
];

void main() {
  group('zero network by default', () {
    final sources = dartSourcesUnder('lib');

    test('there is source to check', () {
      expect(sources, isNotEmpty, reason: 'lib/ is empty.');
    });

    test('no network API outside the two documented call sites', () {
      for (final file in sources) {
        if (hasPrefix(file.path, networkAllowedPrefixes)) continue;

        final found = forbiddenTokensIn(file.code, networkApis);
        expect(
          found,
          isEmpty,
          reason:
              '${file.path} uses $found.\n'
              'MarkLens makes exactly two network calls, both '
              'setting-controlled (CLAUDE.md rule 5). No telemetry, no crash '
              'reporting, no analytics, ever. If this is the update check it '
              'belongs in core/update/; if it is remote image loading it '
              'belongs in features/reader/images/ behind '
              'network.allowRemoteImages.',
        );
      }
    });

    test('the socket exception is one named file, not a widened list', () {
      // The forwarder landed at M1. It is allowed by path so the exception is
      // visible and bounded; the token list stayed exactly as strict, so
      // nothing else in lib/ can open a socket by accident.
      expect(
        networkAllowedPrefixes,
        contains('lib/core/single_instance.dart'),
      );
      expect(networkApis, contains('Socket.connect'));
      expect(
        networkApis,
        isNot(contains('ServerSocket')),
        reason:
            'binding a listener is not egress, and forbidding it would only '
            'push the exception wider',
      );
    });

    test('and it binds loopback, which is the reason it is allowed', () {
      final source = File('lib/core/single_instance.dart').readAsStringSync();
      expect(
        source,
        contains('InternetAddress.loopbackIPv4'),
        reason:
            'the whole justification is that nothing is reachable from '
            'another machine',
      );
      expect(
        source,
        isNot(contains('InternetAddress.anyIPv4')),
        reason: 'binding 0.0.0.0 would make this a real listener on a network',
      );
    });
  });

  group('zero network detector', () {
    test('flags an HttpClient use', () {
      const violating = 'final client = HttpClient();';
      expect(forbiddenTokensIn(violating, networkApis), contains('HttpClient'));
    });

    test('flags a network image', () {
      const violating = 'Image.network(url)';
      expect(
        forbiddenTokensIn(violating, networkApis),
        contains('Image.network'),
      );
    });

    test('does not flag a network mention in a doc comment', () {
      const commented = '/// Never construct an HttpClient here.';
      expect(forbiddenTokensIn(stripComments(commented), networkApis), isEmpty);
    });
  });
}
