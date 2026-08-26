import 'dart:async';
import 'dart:io';

import 'package:marklens/core/models/session_state.dart';
import 'package:marklens/core/storage/json_store.dart';

/// A loaded session, and what happened while loading it.
typedef SessionLoad = ({SessionState state, JsonLoadOutcome outcome});

/// Reads and writes `session.json`.
///
/// Takes its `directory` as a constructor argument and never calls
/// `path_provider`, which is a Flutter plugin (rule 3, `docs/05`).
///
/// **Writes are debounced.** The session changes on every scroll tick and
/// every tab switch, and rule 7 is explicit that persistence must never write
/// on either. [save] records the state and starts a one-second timer; the last
/// state within that window is the one that reaches disk. [flush] forces it —
/// on window close, and on the focus sweep — and [dispose] flushes whatever is
/// still pending, so quitting never loses the last second of a session.
class SessionStore {
  /// Creates a store writing into [directory].
  SessionStore({
    required Directory directory,
    this.debounce = const Duration(seconds: 1),
  }) : _store = JsonStore(directory: directory, name: 'session');

  final JsonStore _store;

  /// How long writes are coalesced for (doc 05: one second).
  final Duration debounce;

  Timer? _timer;
  SessionState? _pending;
  bool _disposed = false;

  /// The file this store owns, for tests and for the About screen.
  File get file => _store.file;

  /// Whether a write is waiting for the debounce window to close.
  bool get hasPending => _pending != null;

  /// Reads the session.
  ///
  /// Always returns a usable session. A missing file is a first run; a corrupt
  /// one is set aside and the session starts empty; a file from a **newer**
  /// MarkLens is backed up rather than read (doc 05, migration policy).
  SessionLoad load() {
    final loaded = _store.load();
    if (loaded.outcome != JsonLoadOutcome.ok) {
      return (state: SessionState.empty, outcome: loaded.outcome);
    }

    final version = loaded.data['version'];
    if (version is int && version > SessionState.schemaVersion) {
      _store.quarantine('bak');
      return (
        state: SessionState.empty,
        outcome: JsonLoadOutcome.futureVersion,
      );
    }

    // Older versions migrate forward here as they appear; v1 is the only shape
    // that has ever been written, so a file with no version is read as v1.
    return (
      state: SessionState.fromJson(loaded.data),
      outcome: JsonLoadOutcome.ok,
    );
  }

  /// Records [state] to be written when the debounce window closes.
  ///
  /// Calling this on every scroll tick is the intended usage; only the last
  /// state in the window is written.
  void save(SessionState state) {
    if (_disposed) {
      return;
    }
    _pending = state;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  /// Writes any pending state immediately.
  ///
  /// Returns whether anything was written — `false` when there was nothing
  /// pending, which is not a failure.
  bool flush() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    if (pending == null) {
      return false;
    }
    _pending = null;
    return _store.save(pending.toJson());
  }

  /// Flushes and stops.
  ///
  /// Quitting must not drop the last second of a session, so this writes what
  /// is pending rather than discarding it.
  void dispose() {
    flush();
    _disposed = true;
  }
}
