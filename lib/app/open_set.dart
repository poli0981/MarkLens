import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/open_set.dart';
import 'package:marklens/core/models/opened_file.dart';

/// Opens, closes, activates and orders documents.
///
/// The sidebar and the tab strip are two views of this one state, which is how
/// they stay independent of each other: neither imports the other, and both
/// reach it through `app/providers.dart` (`docs/02_ARCHITECTURE.md`).
///
/// Nothing here parses anything. Doc 03 is explicit that the sidebar renders
/// from metadata only, and that only the active document is parsed — that is
/// what keeps a thousand restored entries free at startup.
class OpenSetController extends Notifier<OpenSet> {
  @override
  OpenSet build() => OpenSet.empty;

  /// Opens [paths], appending anything new and activating the first of them.
  ///
  /// Deduped by canonical identity, so a file reached twice — through a
  /// symlink, or listed on the command line and also inside an open folder —
  /// is one entry (`docs/03_DATA_FLOW.md`).
  ///
  /// Returns how many of [paths] resolved to a readable file. The caller needs
  /// that to tell "nothing new, they were already open" from "that path is not
  /// a document" — the second deserves a message and the first does not.
  int openPaths(Iterable<String> paths, {bool activate = true}) {
    final files = ref.read(fileServiceProvider);
    final byIdentity = <String, OpenEntry>{
      for (final entry in state.entries) entry.identity: entry,
    };
    final order = <String>[for (final entry in state.entries) entry.identity];
    String? firstOpened;
    var resolved = 0;

    for (final path in paths) {
      final file = files.describe(path);
      if (file == null) {
        continue;
      }
      resolved++;
      firstOpened ??= file.identity;
      if (byIdentity.containsKey(file.identity)) {
        continue;
      }
      byIdentity[file.identity] = OpenEntry(file: file);
      order.add(file.identity);
    }

    if (firstOpened == null) {
      return 0;
    }

    state = state.copyWith(
      entries: <OpenEntry>[for (final id in order) byIdentity[id]!],
    );
    if (activate) {
      this.activate(firstOpened);
    }
    return resolved;
  }

  /// Scans [root] and opens what it finds.
  ///
  /// A scan that hits the cap opens nothing and records the root instead: doc
  /// 07 requires the user be asked "Open first N / Cancel" rather than handed
  /// a silently truncated folder. [acceptCappedScan] is the answer.
  void openFolder(String root) {
    final result = ref.read(fileServiceProvider).scanRoots(<String>[root]);
    if (result.capExceeded) {
      state = state.copyWith(capExceededRoot: root);
      return;
    }
    _adoptRoot(root, result.files);
  }

  /// Opens the first N of a scan the user was warned about.
  void acceptCappedScan() {
    final root = state.capExceededRoot;
    if (root == null) {
      return;
    }
    final result = ref.read(fileServiceProvider).scanRoots(<String>[root]);
    state = state.copyWith(clearCapExceeded: true);
    _adoptRoot(root, result.files);
  }

  /// Drops the pending question without opening anything.
  void cancelCappedScan() => state = state.copyWith(clearCapExceeded: true);

  void _adoptRoot(String root, List<OpenedFile> files) {
    final roots = <String>[
      ...state.roots,
      if (!state.roots.contains(root)) root,
    ];
    state = state.copyWith(roots: roots);
    openPaths(files.map((f) => f.path));
  }

  /// Makes [identity] the showing document.
  void activate(String identity) {
    final entry = state.entryFor(identity);
    if (entry == null) {
      return;
    }
    state = state.copyWith(
      activeIdentity: identity,
      // Activating clears the stale mark: the document is about to be
      // re-read, so the dot has done its job.
      entries: _replace(entry.copyWith(stale: false)),
      recentOrder: <String>[
        identity,
        ...state.recentOrder.where((id) => id != identity),
      ],
    );
  }

  /// Closes [identity], activating its neighbour.
  ///
  /// The path is remembered so `Ctrl+Shift+T` can bring it back — doc 06 lists
  /// reopen in the shortcut inventory, and a close that cannot be undone is
  /// the one destructive-feeling action in a read-only app.
  void close(String identity) {
    final entry = state.entryFor(identity);
    if (entry == null) {
      return;
    }
    final index = state.entries.indexOf(entry);
    final entries = <OpenEntry>[...state.entries]..removeAt(index);
    final recentOrder = <String>[
      ...state.recentOrder.where((id) => id != identity),
    ];

    String? nextActive;
    if (state.activeIdentity == identity) {
      // The most recently used survivor, falling back to the neighbour, so
      // closing a tab lands somewhere the reader was rather than somewhere
      // arbitrary.
      nextActive = recentOrder.isNotEmpty
          ? recentOrder.first
          : (entries.isEmpty
                ? null
                : entries[index < entries.length ? index : entries.length - 1]
                      .identity);
    } else {
      nextActive = state.activeIdentity;
    }

    state = OpenSet(
      entries: entries,
      roots: state.roots,
      activeIdentity: nextActive,
      recentOrder: recentOrder,
      reopenable: <String>[...state.reopenable, entry.file.path],
      capExceededRoot: state.capExceededRoot,
    );
  }

  /// Closes everything, keeping the reopen history.
  void closeAll() {
    state = OpenSet(
      roots: state.roots,
      reopenable: <String>[
        ...state.reopenable,
        for (final entry in state.entries) entry.file.path,
      ],
    );
  }

  /// Reopens the most recently closed document.
  void reopenClosed() {
    if (state.reopenable.isEmpty) {
      return;
    }
    final path = state.reopenable.last;
    state = state.copyWith(
      reopenable: <String>[...state.reopenable]..removeLast(),
    );
    openPaths(<String>[path]);
  }

  /// Moves to the next (`1`) or previous (`-1`) document in MRU order.
  void cycle(int step) {
    if (state.entries.length < 2) {
      return;
    }
    // Cycling walks the MRU list, not the strip: doc 06 asks for MRU order,
    // and the strip keeps its own so tabs do not move under the cursor.
    final order = <String>[
      ...state.recentOrder.where((id) => state.entryFor(id) != null),
      for (final entry in state.entries)
        if (!state.recentOrder.contains(entry.identity)) entry.identity,
    ];
    final current = order.indexOf(state.activeIdentity ?? order.first);
    final next = (current + step) % order.length;
    activate(order[next < 0 ? next + order.length : next]);
  }

  /// Pins or unpins [identity].
  void togglePin(String identity) {
    final entry = state.entryFor(identity);
    if (entry == null) {
      return;
    }
    state = state.copyWith(
      entries: _replace(entry.copyWith(pinned: !entry.pinned)),
    );
  }

  /// Records where [identity] is scrolled to, for the session.
  void recordScroll(String identity, double ratio) {
    final entry = state.entryFor(identity);
    if (entry == null || entry.scroll == ratio) {
      return;
    }
    state = state.copyWith(entries: _replace(entry.copyWith(scroll: ratio)));
  }

  /// Re-reads every entry from disk, for the window-focus sweep.
  ///
  /// A file that has gone keeps its entry and gains the badge; one that
  /// changed while inactive gains the dot (`docs/07_FILES_AND_WATCH.md`).
  void refreshAll() {
    final files = ref.read(fileServiceProvider);
    state = state.copyWith(
      entries: <OpenEntry>[
        for (final entry in state.entries)
          _refreshed(entry, files.refresh(entry.file)),
      ],
    );
  }

  /// Re-reads one entry from disk.
  ///
  /// The targeted half of [refreshAll], for a watch event that named a single
  /// path. `refreshAll` would `stat` up to a thousand entries for one save,
  /// which is the wrong shape for something that fires on every keystroke of
  /// someone else's editor.
  void refreshEntry(String identity) {
    final entry = state.entryFor(identity);
    if (entry == null) {
      return;
    }
    state = state.copyWith(
      entries: _replace(
        _refreshed(entry, ref.read(fileServiceProvider).refresh(entry.file)),
      ),
    );
  }

  /// Marks [identity] changed-on-disk while it was in the background.
  ///
  /// The dot this raises is already drawn by both the tab strip and the
  /// sidebar; until M2 nothing ever set it outside a manual reload.
  void markStale(String identity) {
    final entry = state.entryFor(identity);
    if (entry == null || entry.stale) {
      return;
    }
    state = state.copyWith(entries: _replace(entry.copyWith(stale: true)));
  }

  OpenEntry _refreshed(OpenEntry entry, OpenedFile current) {
    final changed =
        current.modified != entry.file.modified ||
        current.size != entry.file.size;
    return entry.copyWith(
      file: current,
      stale: entry.stale || (changed && entry.identity != state.activeIdentity),
    );
  }

  /// Restores an open set from the session, without parsing anything.
  ///
  /// Entries whose files have gone are kept and badged rather than pruned:
  /// they leave the session only when the user closes them (doc 07).
  void restore({
    required Iterable<({String path, double scroll, bool pinned})> documents,
    required Iterable<String> roots,
    String? activePath,
  }) {
    final files = ref.read(fileServiceProvider);
    final entries = <OpenEntry>[];
    final seen = <String>{};
    String? active;

    for (final document in documents) {
      final file =
          files.describe(document.path) ??
          OpenedFile(
            path: document.path,
            identity: document.path.toLowerCase(),
            modified: DateTime.fromMillisecondsSinceEpoch(0),
            size: 0,
            missing: true,
          );
      if (!seen.add(file.identity)) {
        continue;
      }
      entries.add(
        OpenEntry(
          file: file,
          pinned: document.pinned,
          scroll: document.scroll,
        ),
      );
      if (document.path == activePath) {
        active = file.identity;
      }
    }

    state = OpenSet(
      entries: entries,
      roots: <String>[...roots],
      activeIdentity:
          active ?? (entries.isEmpty ? null : entries.first.identity),
      recentOrder: <String>[?active],
    );
  }

  List<OpenEntry> _replace(OpenEntry updated) => <OpenEntry>[
    for (final entry in state.entries)
      if (entry.identity == updated.identity) updated else entry,
  ];
}

/// The open set provider.
final NotifierProvider<OpenSetController, OpenSet> openSetProvider =
    NotifierProvider<OpenSetController, OpenSet>(OpenSetController.new);
