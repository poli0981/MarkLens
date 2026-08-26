/// `docs/03_DATA_FLOW.md` cold start: the command line names files and
/// folders, and CLAUDE.md rule 9 — a bad command line reports rather than
/// stopping the app before its window exists.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/cli/launch_arguments.dart';

void main() {
  group('paths', () {
    test('everything positional is a path, in order', () {
      final parsed = parseLaunchArguments(<String>['a.md', 'docs', 'b.mdx']);
      expect(parsed.paths, <String>['a.md', 'docs', 'b.mdx']);
      expect(parsed.error, isNull);
    });

    test('no arguments is not an error', () {
      final parsed = parseLaunchArguments(const <String>[]);
      expect(parsed.paths, isEmpty);
      expect(parsed.help, isFalse);
      expect(parsed.version, isFalse);
      expect(parsed.error, isNull);
    });

    test('a path that looks like a flag survives after --', () {
      final parsed = parseLaunchArguments(<String>['--', '--weird-name.md']);
      expect(parsed.paths, <String>['--weird-name.md']);
    });

    test('paths with spaces arrive whole', () {
      final parsed = parseLaunchArguments(<String>[r'C:\My Docs\read me.md']);
      expect(parsed.paths, <String>[r'C:\My Docs\read me.md']);
    });
  });

  group('flags', () {
    test('help, long and short', () {
      expect(parseLaunchArguments(<String>['--help']).help, isTrue);
      expect(parseLaunchArguments(<String>['-h']).help, isTrue);
    });

    test('version, long and short', () {
      expect(parseLaunchArguments(<String>['--version']).version, isTrue);
      expect(parseLaunchArguments(<String>['-v']).version, isTrue);
    });

    test('a flag and a path together', () {
      final parsed = parseLaunchArguments(<String>['--help', 'a.md']);
      expect(parsed.help, isTrue);
      expect(parsed.paths, <String>['a.md']);
    });
  });

  group('a bad command line reports rather than throwing', () {
    test('an unknown flag', () {
      final parsed = parseLaunchArguments(<String>['--nope']);
      expect(parsed.error, isNotNull);
      expect(parsed.paths, isEmpty);
    });

    test('the usage text names the flags it accepts', () {
      final usage = launchUsage();
      expect(usage, contains('--help'));
      expect(usage, contains('--version'));
      expect(usage, contains('marklens'));
    });
  });
}
