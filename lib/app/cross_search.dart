import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/search/in_file_search.dart';
import 'package:marklens/core/search/search_service.dart';

/// The search-across-open-files panel's state (`docs/08_SEARCH.md`).
@immutable
class CrossSearchState {
  /// Creates a state.
  const CrossSearchState({
    this.query = '',
    this.caseSensitive = false,
    this.results = const <FileHits>[],
    this.running = false,
  });

  /// What is being looked for.
  final String query;

  /// Whether case matters.
  final bool caseSensitive;

  /// Files that matched, in open-set order.
  final List<FileHits> results;

  /// Whether a scan is in flight.
  final bool running;

  /// How many matches were found, across every file.
  int get matchCount => results.fold(0, (sum, file) => sum + file.hits.length);

  /// Returns a copy with the given fields replaced.
  CrossSearchState copyWith({
    String? query,
    bool? caseSensitive,
    List<FileHits>? results,
    bool? running,
  }) => CrossSearchState(
    query: query ?? this.query,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    results: results ?? this.results,
    running: running ?? this.running,
  );
}

/// Drives search across the open set, and the jump a result click makes.
///
/// The `Ctrl+Shift+F` activator has been bound to a "not wired up yet"
/// snackbar since M1. This is what it was waiting for.
class CrossSearchController extends Notifier<CrossSearchState> {
  /// How long the query settles before a scan starts.
  ///
  /// Doc 08 asks for "cancellation on query change", and `Isolate.run` cannot
  /// be killed from outside. So a scan is not started for every keystroke, and
  /// a scan that is superseded before it returns has its result thrown away —
  /// which is what cancellation buys, at a cost of one wasted scan rather than
  /// the machinery to stop one.
  static const Duration debounce = Duration(milliseconds: 150);

  Timer? _pending;

  /// Bumped for every scan; a result from an older generation is discarded.
  int _generation = 0;

  @override
  CrossSearchState build() {
    ref.onDispose(() => _pending?.cancel());
    return const CrossSearchState();
  }

  /// Sets the query and schedules a scan.
  void setQuery(String query) {
    state = state.copyWith(query: query);
    _schedule();
  }

  /// Flips case sensitivity and re-scans.
  void toggleCase() {
    state = state.copyWith(caseSensitive: !state.caseSensitive);
    _schedule();
  }

  /// Clears the query and everything it found.
  void clear() {
    _pending?.cancel();
    _generation++;
    state = const CrossSearchState();
  }

  void _schedule() {
    _pending?.cancel();
    if (state.query.isEmpty) {
      _generation++;
      state = state.copyWith(results: const <FileHits>[], running: false);
      return;
    }
    state = state.copyWith(running: true);
    _pending = Timer(debounce, () => unawaited(_run()));
  }

  Future<void> _run() async {
    final generation = ++_generation;
    final query = state.query;
    final caseSensitive = state.caseSensitive;
    // The open set, in the order the sidebar shows it, so results are grouped
    // the way the reader already sees their files.
    final paths = <String>[
      for (final entry in ref.read(openSetProvider).entries)
        if (!entry.file.missing) entry.file.path,
    ];

    final results = await ref
        .read(searchServiceProvider)
        .search(paths: paths, query: query, caseSensitive: caseSensitive);

    if (generation != _generation) {
      // Superseded while it ran. Doc 08's cancellation, from this end.
      return;
    }
    state = state.copyWith(results: results, running: false);
  }

  /// Opens the file a result belongs to and lands on the match.
  ///
  /// [hitIndex] is the match's ordinal within its file, and that is
  /// deliberately what is carried rather than an offset. The scan reads the
  /// file from disk; `SourceBlock` indexes `DocModel.sanitizedSource`, which
  /// has the front matter lifted out, block HTML rewritten and MDX sanitized.
  /// A raw offset handed to `blockIndexOf` would point at the wrong block, and
  /// building a raw-to-sanitized map is what doc 08 refused for find-in-file.
  ///
  /// So the match is re-found in the parsed document: the *n*th hit there is
  /// the *n*th hit here. The two agree exactly for any document whose two
  /// strings are equal, and stay in step for the rest.
  void reveal({required String path, required int hitIndex}) {
    final files = ref.read(fileServiceProvider);
    final file = files.describe(path);
    if (file == null) {
      return;
    }

    final openSet = ref.read(openSetProvider.notifier);
    final wasActive = ref.read(openSetProvider).activeIdentity == file.identity;
    openSet.openPaths(<String>[path]);

    final doc = ref.read(activeDocumentProvider).doc;
    if (doc == null) {
      return;
    }
    final hits = findInSource(
      source: doc.sanitizedSource,
      blocks: doc.blocks,
      query: state.query,
      caseSensitive: state.caseSensitive,
    );
    if (hits.isEmpty) {
      return;
    }
    final hit = hits[hitIndex < hits.length ? hitIndex : hits.length - 1];
    if (hit.blockIndex < 0) {
      return;
    }

    final scroller = ref.read(readerScrollProvider);
    if (wasActive) {
      // Already showing, so the reader will not adopt anything and a pending
      // jump would never be consumed.
      unawaited(scroller.reveal(hit.blockIndex));
    } else {
      scroller.revealWhenAdopted(file.identity, hit.blockIndex);
    }
  }
}

/// The cross-file search provider (`crossSearchState` in doc 03's list).
final NotifierProvider<CrossSearchController, CrossSearchState>
crossSearchProvider = NotifierProvider<CrossSearchController, CrossSearchState>(
  CrossSearchController.new,
);
