/// Resolving a reference written *inside* a document — a link's href, an
/// image's `src` — against the document that wrote it.
///
/// Shared by `link_target.dart` and `core/images/image_source.dart` because
/// they face the same three problems and would otherwise face them twice:
/// percent-encoding that may not be percent-encoding, a query string that is
/// not part of a filename, and a Windows drive letter that `Uri` reads as a
/// scheme.
library;

import 'package:path/path.dart' as p;

/// Percent-decodes [value], or returns it unchanged when decoding it would
/// throw.
///
/// `[text](my%20notes.md)` is an ordinary way to write a filename with a space,
/// and a stray `%` in a filename — `50%_done.md` — is an ordinary way to break
/// a decoder. Checked rather than caught: `Uri.decodeComponent` signals both
/// failures with an `ArgumentError`, and catching an `Error` is catching a bug.
String decodeReference(String value) =>
    _isDecodable(value) ? Uri.decodeComponent(value) : value;

/// The absolute path [reference] names, resolved against [documentPath]'s
/// directory when it is relative.
String resolveAgainstDocument(String reference, String documentPath) =>
    p.isAbsolute(reference)
    ? p.normalize(reference)
    : p.normalize(p.join(p.dirname(documentPath), reference));

/// Whether [reference] names a network location rather than a local path.
///
/// Two shapes, and both are egress wearing a path:
///
/// - A **protocol-relative URL**, `//example.com/tracker.png`. It has no
///   scheme, so it falls through every scheme check ever written.
/// - A **UNC path**, `\\server\share\notes.md`. `Uri` does not parse
///   backslashes at all, so it arrives looking like an ordinary relative path.
///
/// Either one, handed to `File.statSync`, is Windows opening an SMB connection
/// to a host the *document* chose — which is exactly the thing
/// `docs/10_SECURITY_PRIVACY.md` invariant 4 says cannot happen by default.
/// Refused rather than resolved.
bool isNetworkPathReference(String reference) {
  final trimmed = reference.trimLeft();
  return trimmed.startsWith('//') || trimmed.startsWith(r'\\');
}

/// The scheme of [uri], with a Windows drive letter reported as none.
///
/// `Uri` reads `C:/docs/README.md` as scheme `c`. Treating that as a protocol
/// would refuse an ordinary absolute path on the platform this app was written
/// on, so a single-letter scheme is not a scheme here.
String schemeOf(Uri uri) => uri.scheme.length == 1 ? '' : uri.scheme;

/// Whether `Uri.decodeComponent` will accept [value].
///
/// Two conditions, and the second is the one that is easy to miss: every `%`
/// must introduce two hex digits, **and the whole string must be ASCII**.
/// Dart's decoder raises the same "Illegal percent encoding" for a code unit
/// above 127 as it does for a bad escape, so `#tiếng-việt` — an anchor doc 09
/// makes a first-class case — would otherwise take the caller down. A string
/// that is already non-ASCII is already decoded.
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
