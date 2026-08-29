/// Scripts the release workflow executes directly must be executable in git.
///
/// This exists because the release rehearsal failed on exactly this, and
/// because nothing else in the repo could have caught it. The dev machine is
/// Windows, where `core.fileMode` is `false`: `chmod +x` succeeds, changes
/// nothing git records, and the file goes into the index as `100644`. On a
/// Linux runner the checkout then produces a non-executable script and
/// `packaging/linux/build-deb.sh` exits 126, "Permission denied".
///
/// Every local run of those scripts had been `bash packaging/linux/build-deb.sh`
/// — inside the container, where the interpreter is named explicitly and the
/// mode is irrelevant. The one caller that did not name an interpreter was the
/// workflow, which is the one caller that had never run.
///
/// So the mode has to be read from the *index*, not from the filesystem:
/// `File.statSync().mode` on Windows reports something meaningless. That means
/// shelling out to git, which is unusual for this suite and is the only way to
/// see what will actually be checked out somewhere else.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scripts invoked by path, with no interpreter in front of them.
///
/// `AppRun` is here even though `build-appimage.sh` installs it with
/// `install -m 755`: it is the entry point of the AppImage and an
/// unexecutable one is a broken artefact, so the mode should be right in the
/// repo as well as in the output.
const List<String> executableScripts = <String>[
  'packaging/linux/AppRun',
  'packaging/linux/build-appimage.sh',
  'packaging/linux/build-deb.sh',
];

/// Files that are shipped *into* a package with an explicit mode, and therefore
/// do not need one here.
///
/// Listed rather than omitted so the distinction is deliberate: the Debian
/// maintainer scripts must be 755 in the `.deb`, and `build-deb.sh` sets that
/// with `install -m 755`. Marking them executable in the repo too would be
/// harmless and would also hide which mechanism is load-bearing.
const List<String> modeSetAtInstallTime = <String>[
  'packaging/linux/deb/DEBIAN/postinst',
  'packaging/linux/deb/DEBIAN/prerm',
  'packaging/linux/deb/DEBIAN/postrm',
];

/// `path -> mode` as git has it recorded, for the given paths.
Map<String, String> _indexModes(List<String> paths) {
  final result = Process.runSync('git', <String>['ls-files', '-s', ...paths]);
  if (result.exitCode != 0) {
    throw StateError('git ls-files failed: ${result.stderr}');
  }
  final modes = <String, String>{};
  for (final line in (result.stdout as String).split('\n')) {
    if (line.trim().isEmpty) {
      continue;
    }
    // <mode> <sha> <stage>\t<path>
    final tab = line.indexOf('\t');
    modes[line.substring(tab + 1).trim()] = line.substring(0, 6);
  }
  return modes;
}

void main() {
  test('the scripts the workflow runs by path are executable', () {
    final modes = _indexModes(executableScripts);
    for (final script in executableScripts) {
      expect(
        modes[script],
        '100755',
        reason:
            '$script is $modes in the index. On Windows `chmod +x` does not '
            'reach git (core.fileMode=false); use '
            '`git update-index --chmod=+x $script`. Without it the release '
            "workflow's Linux job exits 126 on a fresh checkout.",
      );
    }
  });

  test('and the ones installed with an explicit mode are not', () {
    // A negative control for the rule above, and a check that the distinction
    // is still true: if build-deb.sh ever stops using `install -m 755`, these
    // need the bit and this test says so by failing.
    final modes = _indexModes(modeSetAtInstallTime);
    for (final script in modeSetAtInstallTime) {
      expect(modes[script], '100644', reason: '$script changed mode.');
    }
    expect(
      File('packaging/linux/build-deb.sh').readAsStringSync(),
      contains('install -m 755'),
      reason:
          'The maintainer scripts are 644 in the repo because the build sets '
          'their mode. If it stops doing that, they become 644 in the .deb and '
          'dpkg fails the install after unpacking.',
    );
  });
}
