/// Ordering for file and folder names, so `2.md` sorts before `10.md`.
///
/// Plain string comparison puts `10.md` first, which is right for a computer
/// and wrong for everyone reading a docs folder (`docs/07_FILES_AND_WATCH.md`).
///
/// Hand-written rather than pulled in: the `collection` package has no natural
/// comparator, and doc 13 prefers fifty lines of our own code over a utility
/// dependency.
library;

const int _zero = 0x30;
const int _nine = 0x39;
const int _upperA = 0x41;
const int _upperZ = 0x5A;
const int _caseShift = 0x20;

bool _isDigit(int unit) => unit >= _zero && unit <= _nine;

/// ASCII-only case folding.
///
/// Enough for the filenames this ordering exists to fix, which are the ones
/// that mix digits and Latin letters. Anything outside ASCII compares by code
/// unit — deterministic and stable, just not linguistically sorted. Real
/// locale-aware collation would need `intl`, which `core/` may not import.
int _fold(int unit) =>
    unit >= _upperA && unit <= _upperZ ? unit + _caseShift : unit;

/// Compares [a] and [b] the way a person reading a file list would.
///
/// Runs of digits compare as numbers, everything else compares case-folded.
/// Ties fall through to an exact comparison so the order is total — two names
/// differing only in case must not be reported as equal, or a sort becomes
/// unstable and the sidebar reshuffles between scans.
int compareNatural(String a, String b) {
  var i = 0;
  var j = 0;

  while (i < a.length && j < b.length) {
    final unitA = a.codeUnitAt(i);
    final unitB = b.codeUnitAt(j);

    if (_isDigit(unitA) && _isDigit(unitB)) {
      var endA = i;
      while (endA < a.length && _isDigit(a.codeUnitAt(endA))) {
        endA++;
      }
      var endB = j;
      while (endB < b.length && _isDigit(b.codeUnitAt(endB))) {
        endB++;
      }

      // Compared as digit strings rather than parsed: a version number or an
      // id can be longer than an int, and `int.parse` would throw on it.
      final numberA = _withoutLeadingZeros(a.substring(i, endA));
      final numberB = _withoutLeadingZeros(b.substring(j, endB));
      if (numberA.length != numberB.length) {
        return numberA.length - numberB.length;
      }
      final digits = numberA.compareTo(numberB);
      if (digits != 0) {
        return digits;
      }

      i = endA;
      j = endB;
      continue;
    }

    final foldedA = _fold(unitA);
    final foldedB = _fold(unitB);
    if (foldedA != foldedB) {
      return foldedA - foldedB;
    }
    i++;
    j++;
  }

  if (i < a.length) {
    return 1;
  }
  if (j < b.length) {
    return -1;
  }
  return a.compareTo(b);
}

/// Strips leading zeros, keeping at least one digit so `000` stays a number.
String _withoutLeadingZeros(String digits) {
  var start = 0;
  while (start < digits.length - 1 && digits.codeUnitAt(start) == _zero) {
    start++;
  }
  return digits.substring(start);
}
