/// The two font stacks, in one place, because they were in three.
///
/// `fontFamily: 'monospace'` with a `['Courier New', 'monospace']` fallback was
/// copied verbatim into `reader_style.dart`, `code_block_builder.dart` and
/// `front_matter_panel.dart` — three identical literals that had to be changed
/// together and were guarded by nothing.
/// `test/architecture/no_font_literal_test.dart` is what stops a fourth.
///
/// The families are the ones doc 01 pins and `pubspec.yaml` declares; the
/// bytes are built by `tool/fonts/build_fonts.py`.
///
/// **The fallback lists are not decoration.** Doc 01 promises "system-font
/// fallback stays enabled below the bundled set for emoji and rare scripts",
/// and the bundled Japanese face is a JIS X 0208 subset — so a document using a
/// kanji outside that repertoire, or any script other than Latin and Japanese,
/// or an emoji, resolves through these lists. Setting `fontFamily` without them
/// is how that promise breaks silently.
library;

/// UI and body text. Covers Latin and Vietnamese; Japanese arrives through
/// [sansFallback].
const String sansFamily = 'Noto Sans';

/// Code blocks, inline code, and the raw front-matter view.
const String monoFamily = 'JetBrains Mono';

/// Below [sansFamily]: the bundled Japanese face first, then whatever the OS
/// supplies.
///
/// `Noto Sans JP` has to be named explicitly rather than left to the system,
/// because naming it is the whole point of bundling it — charter principle 1 is
/// that a document looks the same on Windows and Ubuntu, and "the system's
/// Japanese font" is by definition different on each.
const List<String> sansFallback = <String>[
  'Noto Sans JP',
  // The system stacks, in the order each platform resolves them. Neither is
  // present on the other, so listing both is how one constant serves both.
  'Segoe UI', // Windows
  'Noto Sans CJK JP', // Ubuntu, when the distro ships it
  'Ubuntu',
  'DejaVu Sans',
];

/// Below [monoFamily].
///
/// Japanese in a code block is ordinary — a comment, a string literal — and
/// JetBrains Mono has no kana, so the JP face belongs here too. Without it a
/// Japanese comment inside a fenced block renders in whatever the OS picks,
/// which is the one place identical rendering matters most: a code block is
/// where alignment is load-bearing.
const List<String> monoFallback = <String>[
  'Noto Sans JP',
  'Consolas', // Windows
  'Ubuntu Mono',
  'DejaVu Sans Mono',
  'monospace',
];
