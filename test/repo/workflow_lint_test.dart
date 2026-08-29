/// The workflows, checked from the repo rather than from a failed run.
///
/// `.github/workflows/` is the one place where a mistake is both invisible in
/// review and expensive: an unpinned action, a permission left at the default,
/// or a second job that can write to the repository. None of those fails a
/// build — they fail a threat model, quietly, and only once somebody is looking
/// for them.
///
/// Doc 14's non-negotiables are the specification here: least-privilege
/// permissions everywhere, SHA-pinned third-party actions and tools, and Linux
/// artefacts never built outside CI.
///
/// Regex over text, for the reason the rest of `test/repo/` gives:
/// `package:yaml` is transitive-only, so importing it fails `flutter analyze`,
/// which gates every PR.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every workflow in the repo, so a new one cannot arrive unchecked.
List<File> _workflows() =>
    Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _name(File f) => f.uri.pathSegments.last;

/// The `jobname:` → body map of a workflow, split on two-space indentation.
Map<String, String> _jobs(String yaml) {
  final start = yaml.indexOf(RegExp(r'^jobs:$', multiLine: true));
  if (start == -1) {
    return <String, String>{};
  }
  final body = yaml.substring(start);
  final jobs = <String, String>{};
  final headers = RegExp(
    r'^  ([a-z0-9][\w-]*):$',
    multiLine: true,
  ).allMatches(body).toList();
  for (var i = 0; i < headers.length; i++) {
    final end = i + 1 < headers.length ? headers[i + 1].start : body.length;
    jobs[headers[i].group(1)!] = body.substring(headers[i].end, end);
  }
  return jobs;
}

void main() {
  final workflows = _workflows();

  test('there are workflows to check', () {
    expect(workflows, isNotEmpty);
    expect(
      workflows.map(_name),
      contains('release.yml'),
      reason: 'doc 14 describes a release workflow; this is where it is.',
    );
  });

  test('every third-party action is pinned to a full SHA', () {
    // A tag is mutable. `@v5` today and `@v5` next month can be different code
    // running with whatever permissions the job holds - and one of these jobs
    // holds contents: write.
    for (final workflow in workflows) {
      final uses = RegExp(r'uses:\s*([^\s#]+)')
          .allMatches(workflow.readAsStringSync())
          .map((m) => m.group(1)!);
      expect(uses, isNotEmpty, reason: '${_name(workflow)} uses no actions?');
      for (final action in uses) {
        expect(
          action,
          matches(RegExp(r'@[0-9a-f]{40}$')),
          reason:
              '${_name(workflow)} pins $action by tag. Pin the commit SHA and '
              'put the version in a trailing comment, as the others do.',
        );
      }
    }
  });

  test('every workflow declares its permissions at the top', () {
    // Without an explicit block a job inherits the repository default, which
    // may be read-write. Least privilege has to be written down to exist.
    for (final workflow in workflows) {
      expect(
        workflow.readAsStringSync(),
        matches(RegExp(r'^permissions:$', multiLine: true)),
        reason: '${_name(workflow)} has no top-level permissions block.',
      );
    }
  });

  test('exactly one job in the repository can write to it', () {
    // The blast radius. Every artefact download, every build tool, every script
    // in that one job runs with the ability to create releases and push - which
    // is why appimagetool and its runtime are SHA-pinned (doc 11).
    final elevated = <String>[];
    for (final workflow in workflows) {
      _jobs(workflow.readAsStringSync()).forEach((job, body) {
        if (RegExp(r'contents:\s*write').hasMatch(body)) {
          elevated.add('${_name(workflow)}:$job');
        }
      });
    }
    expect(
      elevated,
      <String>['release.yml:publish'],
      reason:
          'doc 14: contents: write is scoped to the publish job only. Anything '
          'else with it is a new place a compromised dependency could reach.',
    );
  });

  test('release.yml reads by default and never publishes by itself', () {
    final release = File('.github/workflows/release.yml').readAsStringSync();
    expect(
      RegExp(
        r'^permissions:\n  contents: read$',
        multiLine: true,
      ).hasMatch(release),
      isTrue,
      reason: 'The top-level default must be read.',
    );
    expect(
      release,
      contains('--draft'),
      reason:
          'Publishing is a human click after the clean-VM smoke and the '
          'read-only audit (doc 15). A draft is also invisible to '
          'UpdateService, which is the correct behaviour until then.',
    );
    expect(
      release,
      isNot(contains('--prerelease')),
      reason:
          'UpdateService ignores prereleases entirely, so marking one would '
          'make the update check a permanent no-op rather than a delayed one.',
    );
  });

  test('no release job runs on a moving image label', () {
    // -latest labels drift: windows-latest moved to a VS2026 image, and
    // ubuntu-26.04 images already exist. A release built on "whatever that
    // means today" is not reproducible, and on Linux the image *is* the glibc
    // floor.
    _jobs(File('.github/workflows/release.yml').readAsStringSync()).forEach((
      job,
      body,
    ) {
      final runsOn = RegExp(r'runs-on:\s*(\S+)').firstMatch(body)?.group(1);
      expect(runsOn, isNotNull, reason: '$job has no runs-on.');
      expect(
        runsOn,
        isNot(contains('-latest')),
        reason: 'release.yml job "$job" runs on $runsOn.',
      );
    });
  });

  test('every job has a timeout', () {
    // doc 14. A hung job holds a runner until the six-hour default expires.
    for (final workflow in workflows) {
      _jobs(workflow.readAsStringSync()).forEach((job, body) {
        expect(
          body,
          contains('timeout-minutes:'),
          reason: '${_name(workflow)}:$job has no timeout-minutes.',
        );
      });
    }
  });

  test('the release verifies the tag against both version copies', () {
    // The cheapest guard against the most expensive mistake: UpdateService
    // parses tag_name and nothing else, so a tag that does not SemVer-parse
    // makes the update check a silent no-op for every user (doc 11).
    final release = File('.github/workflows/release.yml').readAsStringSync();
    expect(release, contains('pubspec.yaml'));
    expect(release, contains('lib/app/version.dart'));
    expect(release, contains('GITHUB_REF_NAME'));
  });
}
