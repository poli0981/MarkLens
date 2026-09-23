/// The prose people read, checked for characters nobody can see.
///
/// Doc 11 carried `VisualStudio<FF>.0\VC\Runtimesd` from M4 to v1.0.1: `\14`
/// and `\x64` had been written as escapes somewhere on the way, the first
/// became a form feed and the second a `d`, and no editor, diff or review
/// showed either. The installer script had the same mangling first, and
/// `inno_script_test.dart` guards it there; this guards the prose, where
/// nothing else would.
///
/// Tab, newline and carriage return are allowed. `test/` is not scanned:
/// `fonts_test.dart` holds NUL bytes on purpose.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _invisible = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

List<File> _prose() => <File>[
  ...Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.md')),
  for (final name in const <String>['README.md', 'CHANGELOG.md', 'CLAUDE.md'])
    File(name),
];

void main() {
  test('no doc carries an invisible control character', () {
    final files = _prose();
    expect(
      files.where((file) => file.path.contains('11_PACKAGING_UPDATE')),
      isNotEmpty,
      reason: 'docs/ was not found - is the test running from the repo root?',
    );

    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _invisible.firstMatch(lines[i]);
        if (match != null) {
          final code = match.group(0)!.codeUnitAt(0);
          offenders.add(
            '${file.path}:${i + 1}: '
            'U+${code.toRadixString(16).padLeft(4, '0').toUpperCase()}',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Invisible in an editor and in review, and usually an escape '
          'sequence that was written out instead of interpreted.',
    );
  });
}
