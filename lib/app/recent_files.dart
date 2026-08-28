import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';

/// Documents opened recently, most recent first
/// (`docs/05_SESSION_AND_SETTINGS.md`, `session.json` `recent`).
///
/// It is **history, not a view of the open set**, and that distinction is the
/// whole feature. Until M3 the list was rebuilt from the open set on every
/// save, so closing a file erased it — which made the one thing a recent list
/// is for, getting back to something you closed, the one thing it could not do.
/// `session.json` has carried the field since M1 with nothing reading it back.
///
/// Three surfaces read it: `Ctrl+P`, File → Open Recent, and the first-run
/// empty state (doc 06).
class RecentFiles extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  /// Puts back what `session.json` remembered.
  ///
  /// Entries are not checked against the filesystem here. A file on a drive
  /// that is not plugged in today is still a file you were reading, and doc 07
  /// is explicit that entries leave only when the user says so.
  void restore(Iterable<String> paths) => state = _capped(<String>[...paths]);

  /// Records that [path] was opened, moving it to the front.
  void record(String path) => state = _capped(<String>[
    path,
    ...state.where((existing) => !_same(existing, path)),
  ]);

  /// Forgets everything.
  void clear() => state = const <String>[];

  List<String> _capped(List<String> paths) {
    final limit = ref.read(settingsProvider).recentLimit;
    final seen = <String>{};
    return <String>[
      for (final path in paths)
        if (path.trim().isNotEmpty && seen.add(path.toLowerCase())) path,
    ].take(limit).toList();
  }

  /// Whether two paths name the same file, as the open set judges it.
  ///
  /// Case-folded, because that is how `OpenedFile.identity` dedupes on Windows
  /// (doc 07) and a recent list that held `README.md` and `readme.md` as two
  /// entries would be showing one file twice.
  static bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();
}

/// The recent-files provider.
final NotifierProvider<RecentFiles, List<String>> recentFilesProvider =
    NotifierProvider<RecentFiles, List<String>>(RecentFiles.new);
