import 'dart:io';

/// Helpers shared by the architecture tests.
///
/// These tests read the source tree as text rather than using the analyzer:
/// the rules they enforce are about *import graphs and forbidden APIs*, which
/// text answers exactly, and a dependency-free check cannot itself drift.

/// One Dart source file, with its path normalised to forward slashes and made
/// relative to the package root so assertions read the same on both OSes.
class SourceFile {
  /// Reads a source file.
  SourceFile(this.path, this.contents);

  /// Package-relative path, e.g. `lib/core/markdown/pipeline.dart`.
  final String path;

  /// The file exactly as written.
  final String contents;

  /// [contents] with comments removed, so a rule cannot be tripped by prose.
  late final String code = stripComments(contents);

  /// Every `import`/`export` URI in the file.
  late final List<String> imports = importsOf(code);

  @override
  String toString() => path;
}

/// Collects every `.dart` file under [directory], recursively.
List<SourceFile> dartSourcesUnder(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const <SourceFile>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map(
        (f) => SourceFile(
          f.path.replaceAll(r'\', '/'),
          f.readAsStringSync(),
        ),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Strips `/* … */` blocks and whole-line `//` and `///` comments.
///
/// Trailing comments on a code line are deliberately left in place: dropping
/// everything after a `//` would also eat the `//` inside a URL literal, and a
/// false negative in an architecture test is worse than a false positive.
String stripComments(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return withoutBlocks
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
}

/// Extracts the URI of every `import` and `export` directive.
List<String> importsOf(String code) => RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
).allMatches(code).map((m) => m.group(1)!).toList();

/// Returns the package name of a `package:` URI, or `null` for `dart:` and
/// relative imports.
String? packageNameOf(String uri) {
  if (!uri.startsWith('package:')) return null;
  return uri.substring('package:'.length).split('/').first;
}

/// Returns every forbidden token from [tokens] that appears in [code].
List<String> forbiddenTokensIn(String code, List<String> tokens) =>
    tokens.where(code.contains).toList();

/// Whether [path] sits under any of [prefixes].
bool hasPrefix(String path, List<String> prefixes) =>
    prefixes.any(path.startsWith);
