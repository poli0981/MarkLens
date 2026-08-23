/// Deterministic generators for the oversized half of the torture corpus
/// (`docs/12_TESTING.md`).
///
/// These documents are generated rather than committed: a 1 MB blob in git is
/// a poor trade against a function that produces the same bytes every time,
/// and the perf numbers only mean something if the input is reproducible.
/// Nothing here uses randomness for exactly that reason.
library;

/// Builds a document of roughly [targetCharacters], cycling through every
/// block type so the scroll benchmark exercises real layout rather than one
/// repeated widget.
///
/// The default produces a little over 1 MB of UTF-8 — the perf harness input,
/// which must scroll at >= 55 fps average (`docs/00_CHARTER.md`). The count is
/// in characters, not bytes, because the document deliberately contains
/// multibyte Vietnamese and Japanese text.
String generateLargeDocument({int targetCharacters = 1024 * 1024}) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('title: Generated torture document')
    ..writeln('generated: true')
    ..writeln('---')
    ..writeln();

  var section = 0;
  while (buffer.length < targetCharacters) {
    section++;
    buffer
      ..writeln('## Section $section')
      ..writeln()
      ..writeln(
        'Paragraph $section with *emphasis*, **strong**, `inline code`, a '
        '[link](https://example.com/$section) and some Vietnamese text: '
        'Tiếng Việt có dấu. Japanese too: 日本語のテキスト.',
      )
      ..writeln()
      ..writeln('- list item ${section}a')
      ..writeln('- list item ${section}b')
      ..writeln('  - nested ${section}c')
      ..writeln()
      ..writeln('- [ ] task ${section}a')
      ..writeln('- [x] task ${section}b')
      ..writeln()
      ..writeln('> Quoted text in section $section.')
      ..writeln()
      ..writeln('```dart')
      ..writeln('void section$section() {')
      ..writeln("  final value = 'section $section';")
      ..writeln('  print(value);')
      ..writeln('}')
      ..writeln('```')
      ..writeln()
      ..writeln('| Column A | Column B | Column C |')
      ..writeln('|---|---|---|')
      ..writeln('| a$section | b$section | c$section |')
      ..writeln('| d$section | e$section | f$section |')
      ..writeln();
  }
  return buffer.toString();
}

/// Builds a table [columns] wide, which must scroll horizontally rather than
/// squash (`docs/04_MARKDOWN_PIPELINE.md`).
String generateWideTable({int columns = 60}) {
  final header = List.generate(columns, (i) => 'Column ${i + 1}');
  final divider = List.filled(columns, '---');
  final buffer = StringBuffer()
    ..writeln('# Wide table')
    ..writeln()
    ..writeln('| ${header.join(' | ')} |')
    ..writeln('| ${divider.join(' | ')} |');
  for (var row = 1; row <= 5; row++) {
    final cells = List.generate(columns, (i) => 'r${row}c${i + 1}');
    buffer.writeln('| ${cells.join(' | ')} |');
  }
  return buffer.toString();
}

/// Builds a table [rows] tall, to see whether the renderer builds table rows
/// lazily or all at once.
String generateTallTable({int rows = 2000}) {
  final buffer = StringBuffer()
    ..writeln('# Tall table')
    ..writeln()
    ..writeln('| id | name | value |')
    ..writeln('|---|---|---|');
  for (var row = 1; row <= rows; row++) {
    buffer.writeln('| $row | name-$row | value-$row |');
  }
  return buffer.toString();
}

/// Builds an MDX document with [count] sibling components — the "10,000
/// sibling components" case from `docs/04_MARKDOWN_PIPELINE.md`.
///
/// The sanitizer must stay linear here and must not recurse per sibling.
String generateManySiblingComponents({int count = 10000}) {
  final buffer = StringBuffer()
    ..writeln("import Widget from './Widget'")
    ..writeln()
    ..writeln('# Many siblings')
    ..writeln();
  for (var i = 1; i <= count; i++) {
    buffer.writeln('<Widget index={$i} label="widget $i" />');
  }
  return buffer.toString();
}

/// Builds a deeply nested MDX document [depth] levels deep, to exercise the
/// bail-out at depth 20 rather than a stack overflow.
String generateDeepMdxNesting({int depth = 50}) {
  final open = StringBuffer();
  final close = StringBuffer();
  for (var i = 1; i <= depth; i++) {
    open.write('<L$i>');
  }
  for (var i = depth; i >= 1; i--) {
    close.write('</L$i>');
  }
  return '# Deep MDX nesting\n\n$open\ncontent\n$close\n';
}
