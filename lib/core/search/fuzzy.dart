/// Subsequence scoring for the quick switcher (`docs/08_SEARCH.md`,
/// `Ctrl+P`).
///
/// Pure Dart. A query matches a candidate when its characters appear in the
/// candidate **in order**, not necessarily adjacent — `rdm` matches `README.md`
/// — and the score says how good that match is, so `rdm` prefers `README.md`
/// over `random-numbers.md` even though both contain the letters.
///
/// The scorer is a small dynamic program rather than a greedy first-match scan,
/// and that is the whole reason it earns a file of its own. Greedy matching
/// takes the *first* place each character fits, so `md` in
/// `markdown/notes.md` matches the `m` and `d` of "markdown" and never sees
/// the extension. Two tables — best score ending in a match here, best score
/// reaching here at all — let a match give up an early position for a better
/// one later, which is what makes word boundaries mean anything.
library;

/// Awarded to every matched character, before bonuses.
const int fuzzyMatchScore = 16;

/// Awarded when a match lands on the first character of the candidate.
const int fuzzyStartBonus = 24;

/// Awarded when a match lands after a separator (`/ \ _ - . space`) or on a
/// camelCase capital — the places a human would say a word begins.
const int fuzzyBoundaryBonus = 18;

/// Awarded when a match directly follows the previous one.
///
/// Larger than the boundary bonus, so a run of adjacent characters beats a
/// scattering of well-placed ones: `read` should prefer `README.md` to
/// `r-e-a-d.md`.
const int fuzzyConsecutiveBonus = 20;

/// Charged for every candidate character skipped between matches.
const int fuzzyGapPenalty = 2;

/// Awarded when every matched character falls inside the last path segment.
///
/// The switcher lists names *and* relative paths (doc 08), so a query has to be
/// able to reach a folder — but a match in the filename is nearly always what
/// was meant, and without this a deeply nested file wins on folder names its
/// reader never typed.
const int fuzzySegmentBonus = 30;

/// Candidates longer than this are scored from their tail.
///
/// The table is `query × candidate`, so an unbounded candidate is an unbounded
/// allocation from a path a document or a folder scan supplied (rule 9). The
/// tail is also the half that matters: it holds the filename.
const int fuzzyCandidateLimit = 256;

/// How good a match [query] is for [candidate], or `null` when it is not a
/// subsequence of it at all.
///
/// Case-insensitive, and an empty query scores zero rather than failing — the
/// switcher opens with an empty query and should list everything.
int? fuzzyScore({required String query, required String candidate}) {
  if (query.isEmpty) {
    return 0;
  }
  if (candidate.isEmpty || query.length > candidate.length) {
    return null;
  }

  final haystack = candidate.length > fuzzyCandidateLimit
      ? candidate.substring(candidate.length - fuzzyCandidateLimit)
      : candidate;
  final lowerQuery = query.toLowerCase();
  final lowerHaystack = haystack.toLowerCase();

  final n = lowerQuery.length;
  final m = lowerHaystack.length;
  if (n > m) {
    return null;
  }

  final bonuses = _bonusesFor(haystack);
  final segmentStart = _lastSegmentStart(haystack);

  // `best[j]`  — best score for the query prefix, reaching candidate index j.
  // `ending[j]` — best score for the query prefix where the last query
  //               character matched *at* j. Kept apart because a run bonus can
  //               only extend a match that ended immediately before it.
  //
  // The base row is zero *everywhere*, not only at index 0: an empty query
  // prefix reaches any candidate index by skipping, and skipping a prefix is
  // free. Charging for it would make `notes` prefer `notes-and-more.md` to
  // `docs/notes.md`, which is not what anyone means. What makes a shorter path
  // win instead is the start bonus, which only the first character can earn.
  var best = List<int?>.filled(m + 1, 0);
  var ending = List<int?>.filled(m + 1, null);
  var endedInSegment = List<bool>.filled(m + 1, true);
  var bestInSegment = List<bool>.filled(m + 1, true);

  for (var i = 1; i <= n; i++) {
    final nextBest = List<int?>.filled(m + 1, null);
    final nextEnding = List<int?>.filled(m + 1, null);
    final nextBestInSegment = List<bool>.filled(m + 1, true);
    final nextEndedInSegment = List<bool>.filled(m + 1, true);

    for (var j = i; j <= m; j++) {
      if (lowerQuery.codeUnitAt(i - 1) == lowerHaystack.codeUnitAt(j - 1)) {
        // Either start a run here, or extend the one that ended at j-1.
        final fromGap = best[j - 1];
        final fromRun = ending[j - 1];
        var score = _minScore;
        var inSegment = true;

        if (fromGap != null) {
          score = fromGap + fuzzyMatchScore + bonuses[j - 1];
          inSegment = bestInSegment[j - 1] && j - 1 >= segmentStart;
        }
        if (fromRun != null) {
          final run = fromRun + fuzzyMatchScore + fuzzyConsecutiveBonus;
          if (run > score) {
            score = run;
            inSegment = endedInSegment[j - 1] && j - 1 >= segmentStart;
          }
        }
        if (score != _minScore) {
          nextEnding[j] = score;
          nextEndedInSegment[j] = inSegment;
        }
      }

      // Reaching j without matching here: either the match ended here, or the
      // best so far carried over one character further, paying for the gap.
      final carried = nextBest[j - 1];
      final skipped = carried == null ? null : carried - fuzzyGapPenalty;
      final landed = nextEnding[j];
      if (landed != null && (skipped == null || landed >= skipped)) {
        nextBest[j] = landed;
        nextBestInSegment[j] = nextEndedInSegment[j];
      } else if (skipped != null) {
        nextBest[j] = skipped;
        nextBestInSegment[j] = nextBestInSegment[j - 1];
      }
    }

    best = nextBest;
    ending = nextEnding;
    bestInSegment = nextBestInSegment;
    endedInSegment = nextEndedInSegment;
  }

  // The answer is the best score **ending in a match**, not the best score
  // carried to the end of the candidate. Reading `best[m]` instead charges the
  // gap penalty for every character after the last match, so `ab` in
  // `crabapple.md` — where the match is early and the tail is long — would be
  // punished for its own extension, and beat by a worse match in a shorter
  // name. That is the sort of thing a switcher gets wrong once and is never
  // trusted again.
  var total = _minScore;
  var inSegment = false;
  for (var j = 1; j <= m; j++) {
    final candidate = ending[j];
    if (candidate != null && candidate > total) {
      total = candidate;
      inSegment = endedInSegment[j];
    }
  }
  if (total == _minScore) {
    return null;
  }
  return inSegment ? total + fuzzySegmentBonus : total;
}

/// Ranks [items] by how well [query] matches `label(item)`, best first.
///
/// Items that do not match at all are dropped. Ties keep the order they were
/// given, which is how the caller's own idea of relevance — most-recently-used
/// first — survives a query that cannot tell two candidates apart.
List<T> fuzzyRank<T>({
  required String query,
  required Iterable<T> items,
  required String Function(T item) label,
  int limit = 20,
}) {
  final scored = <({T item, int score, int order})>[];
  var order = 0;
  for (final item in items) {
    final score = fuzzyScore(query: query, candidate: label(item));
    if (score != null) {
      scored.add((item: item, score: score, order: order));
    }
    order++;
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return <T>[for (final entry in scored.take(limit)) entry.item];
}

const int _minScore = -1 << 30;

/// The positional bonus for a match at each index of [candidate].
List<int> _bonusesFor(String candidate) {
  final bonuses = List<int>.filled(candidate.length, 0);
  for (var i = 0; i < candidate.length; i++) {
    if (i == 0) {
      bonuses[i] = fuzzyStartBonus;
      continue;
    }
    final previous = candidate.codeUnitAt(i - 1);
    final current = candidate.codeUnitAt(i);
    if (_isSeparator(previous)) {
      bonuses[i] = fuzzyBoundaryBonus;
    } else if (_isLower(previous) && _isUpper(current)) {
      // camelCase: the capital is where the second word starts.
      bonuses[i] = fuzzyBoundaryBonus;
    }
  }
  return bonuses;
}

/// Index of the first character of the last path segment.
int _lastSegmentStart(String candidate) {
  for (var i = candidate.length - 1; i >= 0; i--) {
    final unit = candidate.codeUnitAt(i);
    if (unit == 0x2F || unit == 0x5C) {
      return i + 1;
    }
  }
  return 0;
}

bool _isSeparator(int unit) =>
    unit == 0x2F || // /
    unit == 0x5C || // \
    unit == 0x5F || // _
    unit == 0x2D || // -
    unit == 0x2E || // .
    unit == 0x20;

bool _isUpper(int unit) => unit >= 0x41 && unit <= 0x5A;

bool _isLower(int unit) => unit >= 0x61 && unit <= 0x7A;
