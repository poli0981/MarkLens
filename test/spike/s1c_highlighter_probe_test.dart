import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:re_highlight/languages/all.dart' as re_langs;
import 'package:re_highlight/re_highlight.dart' as re;

/// S1c — the highlighter decision (`docs/15_SPIKES_ROADMAP.md`).
///
/// `syntax_highlight` is not in this comparison: 0.5.0 cannot resolve against
/// our pins at all (it drags `win32 <6.0.0` through
/// `super_native_extensions -> device_info_plus`, and `file_picker 12` holds us
/// at `package_info_plus 10.2.1`, which needs `win32 ^6.0.1`), and the 0.4.0
/// that does resolve ships **five** grammars — dart, json, sql, yaml and
/// serverpod_protocol. A Markdown viewer needs rather more than that.
///
/// So this is `highlight 0.7.0` (the pure-Dart engine behind
/// `flutter_highlight`) against `re_highlight 0.0.3`.
///
/// Every test asserts highlighting **actually produced distinct scopes**
/// before drawing conclusions. A highlighter that silently returns one plain
/// span looks exactly like a working one from the outside.
void main() {
  late re.Highlight reHighlight;

  setUpAll(() {
    reHighlight = re.Highlight()
      ..registerLanguages(re_langs.builtinAllLanguages);
  });

  /// Scope names `highlight 0.7.0` assigned, flattened.
  Set<String> hlScopes(String code, String language) {
    final result = hl.highlight.parse(code, language: language);
    final scopes = <String>{};
    void walk(List<hl.Node>? nodes) {
      for (final node in nodes ?? const <hl.Node>[]) {
        if (node.className != null) scopes.add(node.className!);
        walk(node.children);
      }
    }

    walk(result.nodes);
    return scopes;
  }

  /// Scope names `re_highlight 0.0.3` assigned.
  ///
  /// Collected from the engine's own node stream rather than by matching
  /// against a theme. The first version of this probe did the latter, with a
  /// hand-written 17-entry theme, so every scope outside that list vanished —
  /// and `html` and `md` looked unsupported when they are not. The `hl` side
  /// reads `className` straight off the nodes, so this is what makes the two
  /// sides comparable.
  Set<String> reScopes(String code, String language) {
    final result = reHighlight.highlight(code: code, language: language);
    final collector = _ScopeCollector();
    result.render(collector);
    return collector.scopes;
  }

  group('both engines actually highlight', () {
    const dart2 = '''
class Greeter {
  final String name;
  const Greeter(this.name);
  String greet() => 'hello, ' + name;
}
''';

    test('highlight 0.7.0 assigns several distinct scopes', () {
      final scopes = hlScopes(dart2, 'dart');
      expect(
        scopes.length,
        greaterThan(3),
        reason: 'only found $scopes — this is not highlighting',
      );
      expect(scopes, contains('keyword'));
      expect(scopes, contains('string'));
    });

    test('re_highlight 0.0.3 assigns several distinct scopes', () {
      final scopes = reScopes(dart2, 'dart');
      expect(
        scopes.length,
        greaterThan(3),
        reason: 'only found $scopes — this is not highlighting',
      );
      expect(scopes, contains('keyword'));
      expect(scopes, contains('string'));
    });
  });

  group('grammar freshness — Dart 3', () {
    // Records, patterns and class modifiers all postdate the 2020-era
    // grammars in highlight 0.7.0. re_highlight tracks highlight.js v11.9.0.
    const dart3 = dart3Sample;

    test('highlight 0.7.0 on Dart 3 syntax', () {
      final scopes = hlScopes(dart3, 'dart');
      debugPrint('>>> hl 0.7.0 Dart 3 scopes: ${scopes.toList()..sort()}');
      expect(scopes, isNotEmpty, reason: 'nothing was highlighted at all');
    });

    test('re_highlight 0.0.3 on Dart 3 syntax', () {
      final scopes = reScopes(dart3, 'dart');
      debugPrint('>>> re 0.0.3 Dart 3 scopes: ${scopes.toList()..sort()}');
      expect(scopes, isNotEmpty, reason: 'nothing was highlighted at all');
    });

    test('does either grammar know the class modifiers?', () {
      // A fenced code block in a Dart repo's docs is very likely to contain
      // these, so whether they colour as keywords is a real quality question.
      for (final keyword in <String>['sealed', 'base', 'interface', 'mixin']) {
        final source = '$keyword class Foo {}';
        debugPrint(
          '>>> "$keyword class": hl=${hlScopes(source, 'dart')} '
          're=${reScopes(source, 'dart')}',
        );
      }
    });
  });

  group('language aliases a real document will use', () {
    const aliases = <String, String>{
      'js': 'const a = 1;',
      'ts': 'const a: number = 1;',
      'py': 'def f():\n    return 1',
      'sh': 'echo "hi"',
      'yml': 'key: value',
      'html': '<p>text</p>',
      'c#': 'class A { }',
      'toml': 'key = "value"',
      'md': '# heading',
    };

    test('which aliases resolve in each engine', () {
      // Behavioural, not API-level: an alias "resolves" when highlighting
      // through it actually produces scopes. Both engines keep their alias
      // tables private, and producing scopes is what a reader would notice.
      final report = StringBuffer();
      for (final entry in aliases.entries) {
        final hlOk = _survives(() => hlScopes(entry.value, entry.key));
        final reOk = _survives(() => reScopes(entry.value, entry.key));
        report.writeln(
          '  ${entry.key.padRight(6)} '
          'hl:${hlOk == null ? 'THREW' : hlOk.isNotEmpty} '
          're:${reOk == null ? 'THREW' : reOk.isNotEmpty}',
        );
      }
      debugPrint('>>> alias resolution:\n$report');
    });
  });

  group('cost on realistic code', () {
    test('tokenising the same corpus with both engines', () {
      // Every fenced block in the torture corpus, repeated so the numbers rise
      // above timer noise. Both engines walk the same highlight.js grammars,
      // so a large gap here would be surprising and worth knowing about.
      const python = '''
def f(x):
    return [i for i in range(x) if i % 2]
''';
      const json = '''
{"a": 1, "b": [true, null, "x"]}
''';
      const yaml = '''
key: value
list:
  - one
  - two
''';
      const bash = '''
for f in *.md; do echo "hello"; done
''';

      final blocks = <String, String>{
        'dart': dart3Sample * 20,
        'python': python * 60,
        'json': json * 60,
        'yaml': yaml * 60,
        'bash': bash * 60,
      };

      final report = StringBuffer();
      var hlTotal = 0;
      var reTotal = 0;
      for (final entry in blocks.entries) {
        final hlWatch = Stopwatch()..start();
        final hlOut = hlScopes(entry.value, entry.key);
        hlWatch.stop();

        final reWatch = Stopwatch()..start();
        final reOut = reScopes(entry.value, entry.key);
        reWatch.stop();

        hlTotal += hlWatch.elapsedMicroseconds;
        reTotal += reWatch.elapsedMicroseconds;

        // The did-it-happen check: a fast engine that highlighted nothing is
        // not fast, it is broken.
        expect(
          hlOut,
          isNotEmpty,
          reason: 'hl produced no scopes for ${entry.key}',
        );
        expect(
          reOut,
          isNotEmpty,
          reason: 're produced no scopes for ${entry.key}',
        );

        report.writeln(
          '  ${entry.key.padRight(8)} '
          '${entry.value.length.toString().padLeft(6)} chars  '
          'hl ${(hlWatch.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms  '
          're ${(reWatch.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms',
        );
      }
      debugPrint('>>> tokenising cost:');
      debugPrint(report.toString());
      debugPrint(
        '>>> TOTAL  hl ${(hlTotal / 1000).toStringAsFixed(1)} ms  '
        're ${(reTotal / 1000).toStringAsFixed(1)} ms',
      );
    });
  });

  group('an unknown language must never throw', () {
    const code = 'this is not any known language\n  indented line\n';

    test('highlight 0.7.0 degrades quietly', () {
      expect(
        () => hl.highlight.parse(code, language: 'zzunknownlang'),
        returnsNormally,
      );
    });

    test('and what it returns is still the code, unstyled', () {
      // The wrapper needs to know the shape of the fallback, not just that it
      // did not throw: an empty result would silently swallow the block.
      final result = hl.highlight.parse(code, language: 'zzunknownlang');
      final text = StringBuffer();
      void walk(List<hl.Node>? nodes) {
        for (final node in nodes ?? const <hl.Node>[]) {
          if (node.value != null) text.write(node.value);
          walk(node.children);
        }
      }

      walk(result.nodes);
      debugPrint(
        '>>> hl unknown-language fallback: ${text.length} chars, '
        'scopes=${hlScopes(code, 'zzunknownlang')}',
      );
      expect(
        text.toString(),
        contains('not any known language'),
        reason: 'the fallback dropped the code instead of passing it through',
      );
    });

    test('re_highlight 0.0.3 THROWS instead', () {
      // A hard AssertionError: Unknown language. Our CodeHighlighter contract
      // says an unknown language yields plain spans, and CLAUDE.md rule 9 says
      // document content must never crash the app — a fence labelled
      // ```zzunknownlang is exactly that. Usable only behind a
      // known-language check we would have to write and keep correct.
      expect(
        () => reHighlight.highlight(code: code, language: 'zzunknownlang'),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      're_highlight can be asked what it knows, so the check is possible',
      () {
        expect(reHighlight.listLanguages(), contains('dart'));
        expect(reHighlight.listLanguages(), isNot(contains('zzunknownlang')));
      },
    );
  });
}

/// Dart 3 syntax the 2020-era grammars in `highlight 0.7.0` predate: class
/// modifiers, records, and a switch expression with a guarded pattern.
const dart3Sample = '''
sealed class Shape {}

typedef Point = (int x, int y);

String describe(Shape shape) => switch (shape) {
  Circle(radius: final r) when r > 10 => 'big circle',
  _ => 'something else',
};
''';

/// Runs [body], returning its result, or `null` if it threw.
Set<String>? _survives(Set<String> Function() body) {
  try {
    return body();
  } on Object {
    return null;
  }
}

/// Records every scope `re_highlight` opens, with no theme in the way.
class _ScopeCollector implements re.HighlightRenderer {
  final Set<String> scopes = <String>{};

  @override
  void addText(String text) {}

  @override
  void openNode(re.DataNode node) {
    final scope = node.scope;
    if (scope != null) scopes.add(scope);
  }

  @override
  void closeNode(re.DataNode node) {}
}
