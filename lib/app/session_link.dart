import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/storage/json_store.dart';

/// Carries the session between `session.json` and the running app.
///
/// Both directions live here rather than in the store, because the store is
/// pure Dart and knows nothing about the open set or the chrome, and because
/// the *triggers* for a save are a UI concern (`docs/03_DATA_FLOW.md`): a tab
/// opening, a scroll settling, a window moving. The store's job is to write
/// what it is given, atomically and no more than once a second.
class SessionLink {
  /// Creates a link over [ref].
  const SessionLink(this.ref);

  /// The scope this link reads and writes through.
  final Ref ref;

  /// Loads the session and puts the app into it.
  ///
  /// Returns how the load went, so the shell can say something once if the
  /// file had to be set aside (doc 05). Restoring parses nothing: the sidebar
  /// renders from metadata, and only the active document is read — that is
  /// what keeps a thousand restored entries free (doc 03).
  JsonLoadOutcome restore() {
    final loaded = ref.read(sessionStoreProvider).load();
    final state = loaded.state;

    ref
        .read(chromeProvider.notifier)
        .restore(
          sidebarWidth: state.sidebarWidth,
          outlineVisible: state.outlineVisible,
        );
    // The recent list is restored *before* the open set, because opening a
    // document appends to it and the two would otherwise race.
    ref.read(recentFilesProvider.notifier).restore(state.recent);
    ref
        .read(openSetProvider.notifier)
        .restore(
          documents: <({String path, double scroll, bool pinned})>[
            for (final document in state.documents)
              (
                path: document.path,
                scroll: document.scroll,
                pinned: document.pinned,
              ),
          ],
          roots: state.openRoots,
          activePath: state.activePath,
        );

    return loaded.outcome;
  }

  /// Records the current state, debounced by the store.
  ///
  /// Safe to call on every trigger doc 03 lists — the store coalesces a second
  /// of them into one write (rule 7).
  void save() {
    final set = ref.read(openSetProvider);
    final chrome = ref.read(chromeProvider);

    ref
        .read(sessionStoreProvider)
        .save(
          SessionState(
            window: ref.read(windowGeometryProvider),
            sidebarWidth: chrome.sidebarWidth,
            outlineVisible: chrome.outlineVisible,
            openRoots: set.roots,
            documents: <SessionDocument>[
              for (final entry in set.entries)
                SessionDocument(
                  path: entry.file.path,
                  scroll: entry.scroll,
                  pinned: entry.pinned,
                ),
            ],
            activePath: set.active?.file.path,
            recent: _recentPaths(),
          ),
        );
  }

  /// Writes immediately, for window close.
  void flush() => ref.read(sessionStoreProvider).flush();

  /// The recent list, most recent first, capped by the setting.
  ///
  /// **It is not derived from the open set.** It used to be, and that made
  /// "recent" mean "open": closing a file erased it from the list, so the one
  /// thing a recent list exists for — getting back to something you closed —
  /// was the one thing it could not do. `RecentFiles` keeps the history
  /// instead, and this only reads it (`docs/05_SESSION_AND_SETTINGS.md`).
  List<String> _recentPaths() => ref
      .read(recentFilesProvider)
      .take(ref.read(settingsProvider).recentLimit)
      .toList();
}

/// The session link provider.
final Provider<SessionLink> sessionLinkProvider = Provider<SessionLink>(
  SessionLink.new,
);
