/// The GitHub Releases tag check (`docs/11_PACKAGING_UPDATE.md`).
///
/// One of exactly two network calls in the whole app (CLAUDE.md rule 5), which
/// is why `test/architecture/no_network_test.dart` has allowlisted this
/// directory since M0 and nothing has lived here until M3.
///
/// What it does **not** do is as specified as what it does: no downloading, no
/// self-replacement, no telemetry. The request carries nothing but itself — no
/// version, no identifier, no header of ours — so the only thing GitHub learns
/// is that somebody asked, which is what any unauthenticated API call tells a
/// server. Failures are silent and logged (doc 03).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:marklens/core/log/log_buffer.dart';
import 'package:marklens/core/update/semver.dart';

/// A release newer than the running binary.
class AvailableUpdate {
  /// Creates an available update.
  const AvailableUpdate({required this.version, required this.page});

  /// The released version.
  final SemVer version;

  /// Its release page, which is the only thing clicking the banner opens.
  final Uri page;
}

/// The API this check talks to, so a test can answer without a socket.
abstract class UpdateTransport {
  /// Fetches the latest-release document, or `null` when it cannot.
  Future<String?> fetchLatestRelease(Uri endpoint);
}

/// The real transport: one HTTPS GET, `dart:io` only.
///
/// `http` is not a dependency and doc 01 says reaching for it is not allowed —
/// it arrives transitively through `flutter_svg` and is tolerated there,
/// nowhere else.
class HttpUpdateTransport implements UpdateTransport {
  /// Creates a transport.
  const HttpUpdateTransport({this.timeout = const Duration(seconds: 10)});

  /// How long the request may take before it is abandoned.
  ///
  /// A check nobody asked for must never be something anybody waits on.
  final Duration timeout;

  @override
  Future<String?> fetchLatestRelease(Uri endpoint) async {
    if (endpoint.scheme != 'https') {
      // The endpoint is a constant, so this cannot happen by accident — which
      // is exactly why it is worth failing on rather than trusting.
      return null;
    }
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(endpoint);
      // GitHub asks for these two and answers oddly without them. Neither says
      // anything about the machine asking.
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'MarkLens');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        return null;
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } on Exception {
      // Offline, rate-limited, DNS-poisoned, behind a captive portal. None of
      // them is worth a dialog.
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Asks GitHub whether there is a newer release.
class UpdateService {
  /// Creates a service.
  UpdateService({this.transport = const HttpUpdateTransport(), Uri? endpoint})
    : endpoint = endpoint ?? defaultEndpoint;

  /// The endpoint doc 11 names.
  ///
  /// Not a `const` default, because a `Uri` cannot be one — which is worth a
  /// line here rather than a puzzle later.
  static final Uri defaultEndpoint = Uri.parse(
    'https://api.github.com/repos/poli0981/MarkLens/releases/latest',
  );

  /// How often a check may run (`docs/11_PACKAGING_UPDATE.md`).
  static const Duration minimumInterval = Duration(hours: 24);

  /// Where the request goes.
  final UpdateTransport transport;

  /// What it asks.
  final Uri endpoint;

  /// The newest release, if it is newer than [current].
  ///
  /// Returns `null` for "nothing to report", which covers up to date, offline,
  /// rate-limited, and a response that did not parse. The caller cannot tell
  /// those apart on purpose: there is nothing a reader would do differently.
  /// [log] records which it was.
  Future<AvailableUpdate?> check({
    required SemVer current,
    LogBuffer? log,
  }) async {
    final body = await transport.fetchLatestRelease(endpoint);
    if (body == null) {
      log?.warn('update', 'no answer from ${endpoint.host}');
      return null;
    }

    final release = _parse(body);
    if (release == null) {
      log?.warn('update', 'could not read the release document');
      return null;
    }

    if (!release.version.isNewerThan(current)) {
      log?.add('update', 'up to date at $current');
      return null;
    }
    log?.add('update', '${release.version} is available');
    return release;
  }

  /// Whether a check is due, given when the last one ran.
  ///
  /// `null` means never, which is due.
  bool isDue(DateTime? lastCheck, {DateTime? now}) =>
      lastCheck == null ||
      (now ?? DateTime.now()).difference(lastCheck) >= minimumInterval;

  /// Reads the two fields we use out of the release document.
  ///
  /// Everything else GitHub sends is ignored, and a document that is not what
  /// we expected is `null` rather than an exception — it is a response from a
  /// server, which is untrusted input like a document is (rule 9).
  static AvailableUpdate? _parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final tag = decoded['tag_name'];
    if (tag is! String) {
      return null;
    }
    final version = SemVer.tryParse(tag);
    if (version == null) {
      return null;
    }

    // A draft is not released, and a prerelease is not what someone running a
    // stable build is looking for.
    if (decoded['draft'] == true || decoded['prerelease'] == true) {
      return null;
    }

    final url = decoded['html_url'];
    final page = url is String ? Uri.tryParse(url) : null;
    return AvailableUpdate(
      version: version,
      // Falling back to the releases page rather than refusing: knowing there
      // is an update and not being able to reach it is the worst outcome here.
      page: page ?? Uri.parse('https://github.com/poli0981/MarkLens/releases'),
    );
  }
}
