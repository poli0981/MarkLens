/// Which files MarkLens will open, and how a name is taken apart.
///
/// One registry gates folder scans, the file-dialog filter, drag-and-drop and
/// CLI arguments alike (`docs/07_FILES_AND_WATCH.md`), so there is exactly one
/// answer to "is this ours" in the app.
///
/// Paths are pulled apart here rather than with the `path` package. What is
/// actually needed is a basename and an extension, which is a dozen lines;
/// bringing in a dependency for it would owe a pin, a row in doc 01 and a row
/// in the third-party notices (rule 10) to save those lines. Identity is a
/// different problem and is solved in `FileService` with `dart:io`, which
/// resolves symlinks and canonical casing properly.
class ExtensionRegistry {
  /// Creates a registry over [extensions], lower-cased and stripped of any
  /// leading dot the caller may have included.
  factory ExtensionRegistry([Iterable<String> extensions = defaultExtensions]) {
    final normalized = <String>{
      for (final extension in extensions)
        if (_normalize(extension) case final value when value.isNotEmpty) value,
    };
    return ExtensionRegistry._(List<String>.unmodifiable(normalized));
  }

  const ExtensionRegistry._(this.extensions);

  /// The default registry, usable where a `const` default is needed.
  ///
  /// Skips the normalizing factory because [defaultExtensions] is already in
  /// the shape the factory would produce.
  static const ExtensionRegistry standard = ExtensionRegistry._(
    defaultExtensions,
  );

  /// The default set (`docs/05_SESSION_AND_SETTINGS.md`), user-editable.
  static const List<String> defaultExtensions = <String>[
    'md',
    'mdx',
    'markdown',
    'mdown',
    'mkd',
    'mkdn',
    'mdwn',
  ];

  /// The extensions this registry accepts, without dots, lower-cased.
  final List<String> extensions;

  /// Whether [path] is a file MarkLens opens by default.
  ///
  /// Matching is case-insensitive: `README.MD` is a Markdown file.
  bool allows(String path) {
    final extension = extensionOf(path);
    return extension.isNotEmpty && extensions.contains(extension);
  }

  /// Whether [path] is treated as MDX, which selects the sanitizer stage.
  ///
  /// By extension alone — never by sniffing content
  /// (`docs/04_MARKDOWN_PIPELINE.md`).
  bool isMdx(String path) => extensionOf(path) == 'mdx';

  /// The extension of [path], lower-cased and without its dot.
  ///
  /// Empty when the name has no extension, or when the only dot is the one
  /// that makes it a dotfile: `.gitignore` has no extension, it has a name.
  static String extensionOf(String path) {
    final name = basenameOf(path);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  /// The last segment of [path], accepting either separator.
  ///
  /// Both are checked on both platforms: Windows accepts `/` in paths, and a
  /// path can reach us from a CLI argument, a drop target or a session file
  /// written on the other operating system.
  static String basenameOf(String path) {
    var end = path.length;
    // A trailing separator names the same directory, so ignore it.
    while (end > 0 && _isSeparator(path.codeUnitAt(end - 1))) {
      end--;
    }
    var start = end;
    while (start > 0 && !_isSeparator(path.codeUnitAt(start - 1))) {
      start--;
    }
    return path.substring(start, end);
  }

  /// Whether [path]'s own name marks it hidden.
  ///
  /// Dot-prefixed only. **The Windows hidden attribute is not covered**, and
  /// cannot be from pure Dart: `FileStat` exposes mode, type, size and three
  /// timestamps, and nothing about attributes. Reading it would take a win32
  /// dependency, which `core/` may not have (rule 3). Recorded as a gap in
  /// doc 07 rather than silently skipped.
  static bool isHidden(String path) => basenameOf(path).startsWith('.');

  static String _normalize(String extension) =>
      extension.trim().replaceFirst(RegExp(r'^\.+'), '').toLowerCase();

  static bool _isSeparator(int unit) => unit == 0x2F || unit == 0x5C;
}
