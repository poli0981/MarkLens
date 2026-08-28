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
import 'package:marklens/core/links/document_reference.dart';

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
    return AnchorLink(decodeReference(trimmed.substring(1)));
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return UnsupportedLink(href: href);
  }

  final scheme = schemeOf(uri);

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
  final anchor = hash < 0 ? null : decodeReference(trimmed.substring(hash + 1));
  final rawPath = hash < 0 ? trimmed : trimmed.substring(0, hash);
  if (rawPath.isEmpty) {
    return anchor == null ? UnsupportedLink(href: href) : AnchorLink(anchor);
  }

  // Query strings are a web idea; on a path they are part of the name at best
  // and noise at worst. Dropped before resolving, never sent anywhere.
  final withoutQuery = rawPath.split('?').first;
  final decoded = decodeReference(withoutQuery);
  if (isNetworkPathReference(decoded)) {
    // A protocol-relative URL or a UNC path. Not a document on this machine,
    // whatever it looks like — see [isNetworkPathReference].
    return UnsupportedLink(href: href);
  }
  if (!registry.allows(decoded)) {
    // A relative link to something we do not open — an image, a source file,
    // a directory. Doc 03 refuses it with a notice rather than guessing.
    return UnsupportedLink(href: href);
  }

  return DocumentLink(
    path: resolveAgainstDocument(decoded, documentPath),
    anchor: anchor,
  );
}
