/// What an image `src` in a document points at (`docs/04_MARKDOWN_PIPELINE.md`,
/// "Images").
///
/// Pure Dart and **pure**: no filesystem, no network, no `dart:io`. Whether the
/// file is there and how big it is are questions with answers that change, and
/// asking them belongs to the widget that can ask once rather than to a
/// classifier the renderer calls on every rebuild. What is decided here is only
/// what the document said.
///
/// The same shape as `core/links/link_target.dart`, for the same reason:
/// [RemoteImageSource] is the only variant carrying a `Uri`, so the
/// zero-network default (CLAUDE.md rule 5) is a property of the type rather
/// than a check somebody has to remember to write.
library;

import 'package:marklens/core/links/document_reference.dart';

/// Extensions the reader will try to display (`docs/04_MARKDOWN_PIPELINE.md`).
///
/// Anything else is a placeholder. This is an allowlist, not a denylist:
/// doc 10 invariant 3 says a document may not make the app read arbitrary
/// non-image files into memory for display.
const Set<String> imageExtensions = <String>{
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'svg',
};

/// Above this, a local image is a placeholder with a "load anyway" affordance
/// rather than a decode (`docs/04_MARKDOWN_PIPELINE.md`).
const int maxImageBytes = 25 * 1024 * 1024;

/// Where an image comes from.
sealed class ImageSource {
  const ImageSource();

  /// Whether it is an SVG, which needs a different decoder.
  bool get isSvg;
}

/// A file on this machine, resolved against the document's directory.
class LocalImageSource extends ImageSource {
  /// Creates a local source.
  const LocalImageSource({required this.path, required this.isSvg});

  /// Absolute path. Existence and size are the reader's questions, not this
  /// class's.
  final String path;

  @override
  final bool isSvg;
}

/// An `http` or `https` image.
///
/// Loaded only when `network.allowRemoteImages` is on, which it is not by
/// default: a document naming a host is precisely a tracking beacon, and the
/// placeholder shows the URL so the reader can see what was asked for
/// (`docs/10_SECURITY_PRIVACY.md`, invariant 4).
class RemoteImageSource extends ImageSource {
  /// Creates a remote source.
  const RemoteImageSource({required this.uri, required this.isSvg});

  /// The URL, guaranteed to have an `http` or `https` scheme.
  final Uri uri;

  @override
  final bool isSvg;
}

/// An extension outside [imageExtensions], or a `src` with a scheme that is
/// neither local nor `http(s)` — `data:`, `file:`, anything else.
class UnsupportedImageSource extends ImageSource {
  /// Creates a refusal.
  const UnsupportedImageSource({required this.src, required this.reason});

  /// The `src` exactly as the document wrote it.
  final String src;

  /// The word the placeholder names: an extension, or a scheme.
  final String reason;

  @override
  bool get isSvg => false;
}

/// Classifies [src], written in the document at [documentPath].
///
/// Never throws: an unparseable `src` is [UnsupportedImageSource], because an
/// image reference is untrusted input like everything else in the file
/// (CLAUDE.md rule 9).
ImageSource classifyImage({required String src, required String documentPath}) {
  final trimmed = src.trim();
  if (trimmed.isEmpty) {
    return const UnsupportedImageSource(src: '', reason: '');
  }

  final uri = Uri.tryParse(trimmed);
  final scheme = uri == null ? '' : schemeOf(uri);

  if (scheme.isNotEmpty) {
    if (scheme != 'http' && scheme != 'https') {
      // `data:` is the interesting one: an inline payload is a decoder pointed
      // at document content, which is the shape doc 10 invariant 3 refuses.
      return UnsupportedImageSource(src: trimmed, reason: scheme);
    }
    final extension = _extensionOf(uri!.path);
    return imageExtensions.contains(extension)
        ? RemoteImageSource(uri: uri, isSvg: extension == 'svg')
        : UnsupportedImageSource(src: trimmed, reason: extension);
  }

  // A query string is a web idea; on a path it is noise. Dropped before the
  // extension is read, or `logo.png?v=2` would look like a `.png?v=2` file.
  final decoded = decodeReference(trimmed.split('?').first);
  if (isNetworkPathReference(decoded)) {
    // `//example.com/tracker.png` has no scheme, so it reaches here looking
    // local — and statting it on Windows is an SMB connection to a host the
    // document named. The corpus has one; that is how this was found.
    return UnsupportedImageSource(src: trimmed, reason: '');
  }
  final extension = _extensionOf(decoded);
  if (!imageExtensions.contains(extension)) {
    return UnsupportedImageSource(src: trimmed, reason: extension);
  }

  return LocalImageSource(
    path: resolveAgainstDocument(decoded, documentPath),
    isSvg: extension == 'svg',
  );
}

/// The extension of [path], lower-cased and without its dot.
String _extensionOf(String path) {
  final separator = path.lastIndexOf(RegExp(r'[/\\]'));
  final name = separator < 0 ? path : path.substring(separator + 1);
  final dot = name.lastIndexOf('.');
  // A leading dot makes a name, not an extension: `.gitignore` has no
  // extension — the same rule `ExtensionRegistry` uses.
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}
