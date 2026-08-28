/// What a link in a rendered document points at (`docs/03_DATA_FLOW.md`,
/// "Link click routing").
///
/// Pure Dart, and deliberately the *whole* decision: `docs/10_SECURITY_PRIVACY.md`
/// invariant 2 says document content never reaches a process argument, and that
/// external links are shelled out only after an `http`/`https` scheme check.
/// Putting the check here rather than at the call site means there is exactly
/// one place to read, one place to test, and no path to `url_launcher` that
/// skipped it — [ExternalLink] is the only variant that carries a URI at all.
library;

import 'package:marklens/core/files/extension_registry.dart';
import 'package:path/path.dart' as p;

/// Where a link goes.
sealed class LinkTarget {
  const LinkTarget();
}

/// A `#heading` in the document already open.
class AnchorLink extends LinkTarget {
  /// Creates an anchor target.
  const AnchorLink(this.slug);

  /// The GitHub-style slug, without its `#` (`docs/04_MARKDOWN_PIPELINE.md`).
  final String slug;
}

/// Another document MarkLens opens, optionally at one of its headings.
class DocumentLink extends LinkTarget {
  /// Creates a document target.
  const DocumentLink({required this.path, this.anchor});

  /// Absolute path, resolved against the linking document's directory.
  final String path;

  /// The heading to land on, or `null` for the top.
  final String? anchor;
}

/// An `http` or `https` URL, for the system browser.
///
/// The only variant that may reach `url_launcher`.
class ExternalLink extends LinkTarget {
  /// Creates an external target.
  const ExternalLink(this.uri);

  /// The URL, guaranteed to have an `http` or `https` scheme.
  final Uri uri;
}

/// Anything else: `javascript:`, `file:`, `mailto:`, a custom scheme, a
/// relative path to something MarkLens does not open, or a href it cannot
/// parse at all.
///
/// Refused with a notice, never followed (`docs/10_SECURITY_PRIVACY.md`).
class UnsupportedLink extends LinkTarget {
  /// Creates a refusal.
  const UnsupportedLink({required this.href, this.scheme});

  /// The href exactly as the document wrote it.
  final String href;

  /// Its scheme, when it had one — what the notice names.
  final String? scheme;
}

/// The two schemes that may be handed to the system browser.
const Set<String> externalLinkSchemes = <String>{'http', 'https'};

/// Classifies [href], written in the document at [documentPath].
///
/// Never throws: an unparseable href is [UnsupportedLink], because a link a
/// reader clicked is untrusted input like everything else in the file
/// (CLAUDE.md rule 9).
LinkTarget classifyLink({
  required String href,
  required String documentPath,
  ExtensionRegistry registry = ExtensionRegistry.standard,
}) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) {
    return UnsupportedLink(href: href);
  }

  if (trimmed.startsWith('#')) {
    return AnchorLink(_decode(trimmed.substring(1)));
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return UnsupportedLink(href: href);
  }

  // A one-letter scheme is a Windows drive letter, not a protocol. `Uri` reads
  // `C:/docs/README.md` as scheme `c`, and refusing it would refuse an
  // ordinary absolute path on the platform this app was written on.
  final scheme = uri.scheme.length == 1 ? '' : uri.scheme;

  if (scheme.isNotEmpty) {
    if (!externalLinkSchemes.contains(scheme)) {
      return UnsupportedLink(href: href, scheme: scheme);
    }
    // A scheme with no host is not somewhere a browser can go, and is the
    // shape `http:` tricks take.
    return uri.host.isEmpty
        ? UnsupportedLink(href: href, scheme: scheme)
        : ExternalLink(uri);
  }

  final hash = trimmed.indexOf('#');
  final anchor = hash < 0 ? null : _decode(trimmed.substring(hash + 1));
  final rawPath = hash < 0 ? trimmed : trimmed.substring(0, hash);
  if (rawPath.isEmpty) {
    return anchor == null ? UnsupportedLink(href: href) : AnchorLink(anchor);
  }

  // Query strings are a web idea; on a path they are part of the name at best
  // and noise at worst. Dropped before resolving, never sent anywhere.
  final withoutQuery = rawPath.split('?').first;
  final decoded = _decode(withoutQuery);
  if (!registry.allows(decoded)) {
    // A relative link to something we do not open — an image, a source file,
    // a directory. Doc 03 refuses it with a notice rather than guessing.
    return UnsupportedLink(href: href);
  }

  final directory = p.dirname(documentPath);
  final resolved = p.isAbsolute(decoded)
      ? p.normalize(decoded)
      : p.normalize(p.join(directory, decoded));

  return DocumentLink(path: resolved, anchor: anchor);
}

/// Percent-decodes [value], or returns it unchanged when decoding it would
/// throw.
///
/// `[text](my%20notes.md)` is an ordinary way to write a filename with a space,
/// and a stray `%` in a filename — `50%_done.md` — is an ordinary way to break
/// a decoder. Checked rather than caught: `Uri.decodeComponent` signals both
/// failures with an `ArgumentError`, and catching an `Error` is catching a bug.
String _decode(String value) =>
    _isDecodable(value) ? Uri.decodeComponent(value) : value;

/// Whether `Uri.decodeComponent` will accept [value].
///
/// Two conditions, and the second is the one that is easy to miss: every `%`
/// must introduce two hex digits, **and the whole string must be ASCII**.
/// Dart's decoder raises the same "Illegal percent encoding" for a code unit
/// above 127 as it does for a bad escape, so `#tiếng-việt` — an anchor doc 09
/// makes a first-class case — would otherwise take the classifier down. A
/// string that is already non-ASCII is already decoded.
bool _isDecodable(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit > 127) {
      return false;
    }
    if (unit != 0x25) {
      continue;
    }
    if (i + 2 >= value.length ||
        !_isHexDigit(value.codeUnitAt(i + 1)) ||
        !_isHexDigit(value.codeUnitAt(i + 2))) {
      return false;
    }
  }
  return true;
}

bool _isHexDigit(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x46) ||
    (unit >= 0x61 && unit <= 0x66);
