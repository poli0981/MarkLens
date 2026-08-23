/// GitHub-compatible heading anchors.
///
/// The algorithm, per `docs/04_MARKDOWN_PIPELINE.md`: lowercase the heading's
/// rendered text, strip punctuation, turn spaces into hyphens, and give
/// duplicate slugs a `-1`, `-2`, … suffix.
///
/// Pure Dart, no Flutter (CLAUDE.md rule 3). Used by the outline, `#anchor`
/// links, and cross-file `file.md#anchor` links — all three must agree, which
/// is why there is exactly one implementation.
library;

/// Characters that survive slugification: letters, combining marks, digits,
/// underscore, hyphen and the space that later becomes a hyphen.
///
/// Marks (`\p{M}`) matter: decomposed Vietnamese keeps its diacritics as
/// separate combining characters, and dropping them would collide
/// `tiếng-việt` with `ting-vit`.
final RegExp _disallowed = RegExp(r'[^\p{L}\p{M}\p{N} _-]', unicode: true);

/// Slugifies one heading's text, without any duplicate handling.
///
/// Use [HeadingSlugger] instead when slugging a whole document — anchors have
/// to be unique per document, and that is state this function does not keep.
String slugifyHeading(String text) =>
    text.trim().toLowerCase().replaceAll(_disallowed, '').replaceAll(' ', '-');

/// Assigns unique anchors to the headings of a single document.
///
/// One instance per document, fed headings in document order:
///
/// ```dart
/// final slugger = HeadingSlugger();
/// slugger.slug('Setup');  // 'setup'
/// slugger.slug('Setup');  // 'setup-1'
/// ```
class HeadingSlugger {
  /// For each slug already handed out, the highest suffix used for it.
  final Map<String, int> _counts = <String, int>{};

  /// Returns the anchor for [headingText], unique among the headings this
  /// instance has already seen.
  String slug(String headingText) {
    final base = slugifyHeading(headingText);
    final seen = _counts[base];
    if (seen == null) {
      _counts[base] = 0;
      return base;
    }

    // A heading can also collide with a slug that was itself a suffixed
    // duplicate ('setup 1' and a second 'setup' both want 'setup-1'), so keep
    // counting until an unused one turns up.
    var suffix = seen + 1;
    var candidate = '$base-$suffix';
    while (_counts.containsKey(candidate)) {
      suffix++;
      candidate = '$base-$suffix';
    }
    _counts[base] = suffix;
    _counts[candidate] = 0;
    return candidate;
  }

  /// Forgets every slug handed out so far, for reuse on another document.
  void reset() => _counts.clear();
}
