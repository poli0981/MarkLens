import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/core/links/link_target.dart';
import 'package:url_launcher/url_launcher.dart';

/// The seam over `url_launcher` — the one place in the app that hands anything
/// to the operating system.
///
/// A seam for the same two reasons `WindowLink`, `WatchLink` and
/// `FilePickerPrompt` are: a platform channel does not exist in a widget test,
/// and some of these calls return a future that never completes rather than
/// failing, so a `try` cannot catch them.
///
/// It takes a [Uri] rather than a string, and `LinkRouter` only ever builds one
/// from an [ExternalLink] — which by construction has an `http` or `https`
/// scheme. That is `docs/10_SECURITY_PRIVACY.md` invariant 2 made structural:
/// there is no overload here that could be handed a `javascript:` href.
abstract class LauncherLink {
  /// Opens [uri] in whatever the system uses for it.
  ///
  /// Returns whether the platform accepted it.
  Future<bool> open(Uri uri);

  /// Shows [directory] in the system file manager.
  ///
  /// Doc 06's sidebar context menu and its missing-file body both offer this,
  /// and it is the one place MarkLens deliberately hands a **local path** to
  /// the operating system. Doc 10 invariant 2 says document content never
  /// reaches a process argument, and this is not document content: it is a
  /// folder the reader opened themselves. It still goes through a `file:` URI
  /// and `url_launcher` rather than `Process.run`, so there is no command line
  /// for a filename to be interesting inside of.
  Future<bool> reveal(String directory);
}

/// The real launcher.
class PlatformLauncherLink implements LauncherLink {
  /// Creates a launcher.
  const PlatformLauncherLink();

  @override
  Future<bool> open(Uri uri) async {
    // Belt and braces. The classifier already guarantees this, and the
    // guarantee is worth restating at the boundary it protects: everything
    // upstream of here is derived from an untrusted document.
    if (!externalLinkSchemes.contains(uri.scheme)) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // A desktop with no browser registered is not an error worth a dialog;
      // the caller shows a notice either way.
      return false;
    }
  }

  @override
  Future<bool> reveal(String directory) async {
    try {
      // `Uri.file` percent-encodes the path, so a folder with a space or a `#`
      // in its name survives — which is precisely what building the string by
      // hand would get wrong.
      return await launchUrl(Uri.file(directory));
    } on Object {
      return false;
    }
  }
}

/// What a widget test gets: records what it was asked to open, opens nothing.
class RecordingLauncherLink implements LauncherLink {
  /// Creates a recording launcher.
  RecordingLauncherLink({this.succeeds = true});

  /// Whether [open] reports success.
  final bool succeeds;

  /// Every URI handed over, in order.
  final List<Uri> opened = <Uri>[];

  /// Every directory it was asked to reveal, in order.
  final List<String> revealed = <String>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }

  @override
  Future<bool> reveal(String directory) async {
    revealed.add(directory);
    return succeeds;
  }
}

/// The launcher provider, overridden with [RecordingLauncherLink] in tests.
final Provider<LauncherLink> launcherLinkProvider = Provider<LauncherLink>(
  (ref) => const PlatformLauncherLink(),
);
