/// Just enough SemVer to answer one question: is the tag on GitHub newer than
/// the version this binary reports (`docs/11_PACKAGING_UPDATE.md`)?
///
/// Pure Dart, and deliberately not a dependency: doc 13 prefers fifty lines of
/// our own code to a utility package, and the comparison a release check needs
/// is the well-specified half of the standard.
library;

/// A parsed `major.minor.patch[-prerelease]` version.
class SemVer implements Comparable<SemVer> {
  /// Creates a version.
  const SemVer(this.major, this.minor, this.patch, [this.prerelease]);

  /// Parses [value], or returns `null` when it is not a version.
  ///
  /// A leading `v` is stripped, because that is how the tags are written
  /// (doc 11). Build metadata after `+` is dropped: SemVer says it takes no
  /// part in precedence, and `0.1.0+7` and `0.1.0+8` really are the same
  /// release.
  static SemVer? tryParse(String value) {
    var text = value.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }
    final plus = text.indexOf('+');
    if (plus >= 0) {
      text = text.substring(0, plus);
    }

    String? prerelease;
    final dash = text.indexOf('-');
    if (dash >= 0) {
      prerelease = text.substring(dash + 1);
      text = text.substring(0, dash);
      if (prerelease.isEmpty) {
        return null;
      }
    }

    final parts = text.split('.');
    if (parts.length != 3) {
      return null;
    }
    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0) {
        return null;
      }
      numbers.add(number);
    }
    return SemVer(numbers[0], numbers[1], numbers[2], prerelease);
  }

  /// Major version.
  final int major;

  /// Minor version.
  final int minor;

  /// Patch version.
  final int patch;

  /// The `-rc.1` part, or `null` for a release.
  final String? prerelease;

  /// Whether this is a pre-release.
  bool get isPrerelease => prerelease != null;

  @override
  int compareTo(SemVer other) {
    final byMajor = major.compareTo(other.major);
    if (byMajor != 0) {
      return byMajor;
    }
    final byMinor = minor.compareTo(other.minor);
    if (byMinor != 0) {
      return byMinor;
    }
    final byPatch = patch.compareTo(other.patch);
    if (byPatch != 0) {
      return byPatch;
    }
    return _comparePrerelease(prerelease, other.prerelease);
  }

  /// Whether this version is strictly newer than [other].
  bool isNewerThan(SemVer other) => compareTo(other) > 0;

  @override
  String toString() =>
      '$major.$minor.$patch${prerelease == null ? '' : '-$prerelease'}';

  // No `==`. Overriding it here would need `@immutable`, which would need
  // `meta` as a direct dependency, which is a package for one annotation —
  // exactly the trade doc 13 says not to make. Callers compare with
  // [isNewerThan] or [compareTo], which is what a version is for.

  /// SemVer §11: a version *with* a pre-release is lower than one without,
  /// and two pre-releases compare identifier by identifier — numeric ones
  /// numerically, and numeric below alphanumeric.
  ///
  /// This matters in exactly one direction and it is the one that would be
  /// embarrassing: without it, someone running `1.0.0` would be told that
  /// `1.0.0-rc.1` is an upgrade.
  static int _comparePrerelease(String? a, String? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }

    final left = a.split('.');
    final right = b.split('.');
    for (var i = 0; i < left.length && i < right.length; i++) {
      final result = _compareIdentifier(left[i], right[i]);
      if (result != 0) {
        return result;
      }
    }
    return left.length.compareTo(right.length);
  }

  static int _compareIdentifier(String a, String b) {
    final left = int.tryParse(a);
    final right = int.tryParse(b);
    if (left != null && right != null) {
      return left.compareTo(right);
    }
    if (left != null) {
      return -1;
    }
    if (right != null) {
      return 1;
    }
    return a.compareTo(b);
  }
}
