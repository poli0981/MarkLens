import 'package:flutter_test/flutter_test.dart';
import 'package:marklens/core/markdown/slug.dart';

/// Cases required by `docs/12_TESTING.md`: dedupe, punctuation, Vietnamese
/// diacritics, Japanese.
void main() {
  group('slugifyHeading', () {
    test('lowercases and turns spaces into hyphens', () {
      expect(slugifyHeading('Getting Started'), 'getting-started');
    });

    test('trims surrounding whitespace', () {
      expect(slugifyHeading('   Intro   '), 'intro');
    });

    test('strips punctuation', () {
      expect(slugifyHeading("What's new?"), 'whats-new');
      expect(slugifyHeading('2. Setup'), '2-setup');
    });

    test('keeps hyphens, underscores and digits', () {
      expect(slugifyHeading('read-only'), 'read-only');
      expect(slugifyHeading('snake_case'), 'snake_case');
      expect(slugifyHeading('Chapter 12'), 'chapter-12');
    });

    test('does not collapse runs of spaces, matching GitHub', () {
      // '+' and '&' are removed, and each remaining space becomes its own
      // hyphen — GitHub produces 'c--rust' here, not 'c-rust'.
      expect(slugifyHeading('C++ & Rust'), 'c--rust');
    });

    test('preserves Vietnamese letters', () {
      expect(slugifyHeading('Cài đặt nhanh'), 'cài-đặt-nhanh');
    });

    test('preserves combining marks in decomposed Vietnamese', () {
      // 'Tiếng Việt' written with combining marks rather than precomposed
      // characters. Dropping the marks would collide with 'tieng-viet'.
      const decomposed = 'Tiếng Việt';
      final slug = slugifyHeading(decomposed);
      expect(slug, contains('́'), reason: 'acute accent was stripped');
      expect(slug, contains('̣'), reason: 'dot below was stripped');
      expect(slug, isNot(equals('tieng-viet')));
    });

    test('preserves Japanese and strips the punctuation around it', () {
      expect(slugifyHeading('はじめに'), 'はじめに');
      expect(slugifyHeading('設定 · 詳細'), '設定--詳細');
    });

    test('an empty heading slugs to an empty string, not an error', () {
      expect(slugifyHeading(''), '');
      expect(slugifyHeading('!!!'), '');
    });
  });

  group('HeadingSlugger', () {
    test('leaves the first occurrence unsuffixed', () {
      final slugger = HeadingSlugger();
      expect(slugger.slug('Setup'), 'setup');
    });

    test('suffixes repeats in document order', () {
      final slugger = HeadingSlugger();
      expect(slugger.slug('Setup'), 'setup');
      expect(slugger.slug('Setup'), 'setup-1');
      expect(slugger.slug('Setup'), 'setup-2');
    });

    test('skips a suffix already taken by a real heading', () {
      // 'Setup 1' legitimately owns 'setup-1', so the second 'Setup' has to
      // move past it rather than collide.
      final slugger = HeadingSlugger();
      expect(slugger.slug('Setup'), 'setup');
      expect(slugger.slug('Setup 1'), 'setup-1');
      expect(slugger.slug('Setup'), 'setup-2');
    });

    test('treats headings that slugify identically as duplicates', () {
      final slugger = HeadingSlugger();
      expect(slugger.slug('Read-only!'), 'read-only');
      expect(slugger.slug('read-only'), 'read-only-1');
    });

    test('dedupes empty headings too', () {
      final slugger = HeadingSlugger();
      expect(slugger.slug(''), '');
      expect(slugger.slug('###'), '-1');
    });

    test('reset starts a fresh document', () {
      final slugger = HeadingSlugger()
        ..slug('Setup')
        ..reset();
      expect(slugger.slug('Setup'), 'setup');
    });
  });
}
