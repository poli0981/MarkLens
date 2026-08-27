import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/search/in_file_search.dart';

/// The find bar's state (`docs/08_SEARCH.md`, "Find in file").
@immutable
class FindState {
  /// Creates a find state.
  const FindState({
    this.visible = false,
    this.query = '',
    this.caseSensitive = false,
    this.hits = const <FindHit>[],
    this.current = -1,
  });

  /// Whether the bar is showing.
  final bool visible;

  /// What is being looked for.
  final String query;

  /// Whether case matters.
  final bool caseSensitive;

  /// Every match, in document order.
  final List<FindHit> hits;

  /// Index into [hits] of the one the reader is on, or `-1`.
  final int current;

  /// The match the reader is on, or `null`.
  FindHit? get currentHit =>
      current >= 0 && current < hits.length ? hits[current] : null;

  /// Returns a copy with the given fields replaced.
  FindState copyWith({
    bool? visible,
    String? query,
    bool? caseSensitive,
    List<FindHit>? hits,
    int? current,
  }) => FindState(
    visible: visible ?? this.visible,
    query: query ?? this.query,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    hits: hits ?? this.hits,
    current: current ?? this.current,
  );
}

/// Drives find-in-file: the query, the match list, and which one you are on.
///
/// The `Ctrl+F` activator has existed since M1 bound to a "not wired up yet"
/// snackbar. This is what it was waiting for.
class FindController extends Notifier<FindState> {
  @override
  FindState build() => const FindState();

  /// Opens the bar, keeping whatever was last searched for.
  void open() {
    state = state.copyWith(visible: true);
    _recompute();
  }

  /// Closes the bar and clears the highlighting.
  void close() {
    state = const FindState();
    _publishHighlights();
  }

  /// Sets the query and re-runs the search.
  void setQuery(String query) {
    state = state.copyWith(query: query);
    _recompute();
  }

  /// Flips case sensitivity and re-runs the search.
  void toggleCase() {
    state = state.copyWith(caseSensitive: !state.caseSensitive);
    _recompute();
  }

  /// Moves to the next match, wrapping at the end.
  void next() => _step(1);

  /// Moves to the previous match, wrapping at the start.
  void previous() => _step(-1);

  void _step(int direction) {
    if (state.hits.isEmpty) {
      return;
    }
    final count = state.hits.length;
    // Wrapping in both directions: a find bar that stops at the end is a find
    // bar you have to close and reopen.
    final next = (state.current + direction + count) % count;
    state = state.copyWith(current: next);
    _publishHighlights();
    _revealCurrent();
  }

  void _recompute() {
    final doc = ref.read(activeDocumentProvider).doc;
    final hits = doc == null
        ? const <FindHit>[]
        : findInSource(
            source: doc.sanitizedSource,
            blocks: doc.blocks,
            query: state.query,
            caseSensitive: state.caseSensitive,
          );

    state = state.copyWith(hits: hits, current: hits.isEmpty ? -1 : 0);
    _publishHighlights();
    if (hits.isNotEmpty) {
      _revealCurrent();
    }
  }

  void _publishHighlights() {
    // The reader is marked through the scroller, which already carries the
    // pulse and is already threaded to every block. Nothing has to be passed
    // down through the reader for a keystroke to change a tint.
    ref.read(readerScrollProvider).highlightedBlocks.value = <int>{
      for (final hit in state.hits)
        if (hit.blockIndex >= 0) hit.blockIndex,
    };
  }

  void _revealCurrent() {
    final hit = state.currentHit;
    if (hit == null || hit.blockIndex < 0) {
      return;
    }
    unawaited(ref.read(readerScrollProvider).reveal(hit.blockIndex));
  }
}

/// The find-in-file provider.
final NotifierProvider<FindController, FindState> findProvider =
    NotifierProvider<FindController, FindState>(FindController.new);
