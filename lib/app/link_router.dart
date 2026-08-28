import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marklens/app/providers.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/links/link_target.dart';

/// What following a link did, for the notice the shell shows afterwards.
enum LinkOutcomeKind {
  /// Scrolled to a heading in the document already open.
  anchor,

  /// Opened, or activated, another document.
  document,

  /// Handed a URL to the system browser.
  external,

  /// Refused: not `http`, `https`, or a document MarkLens opens.
  unsupported,

  /// The document the link named is not there.
  missingTarget,

  /// The document opened, but it has no heading with that slug.
  missingAnchor,

  /// The platform would not open the URL.
  launchFailed,
}

/// The result of following a link: what happened, and the one word a notice
/// needs to say which link it was about.
typedef LinkOutcome = ({LinkOutcomeKind kind, String? detail});

/// Routes a link click from a rendered document (`docs/03_DATA_FLOW.md`).
///
/// Lives in `app/` rather than in the reader because more than one feature
/// needs it — the reader raises the taps, and the outline, the anchor jumps and
/// (from M3 on) the search panel all drive the same scroller underneath. That
/// is doc 02's test for where widget-layer state belongs: "how many features
/// need it", not "where does it feel like it lives".
///
/// **It decides nothing about safety itself.** [classifyLink] does, in pure
/// Dart, and this class can only act on what it is handed: an [ExternalLink] is
/// the only variant carrying a URI, so there is no branch here that could put a
/// `javascript:` href in front of the operating system
/// (`docs/10_SECURITY_PRIVACY.md`, invariant 2).
class LinkRouter {
  /// Creates a router over [ref].
  const LinkRouter(this.ref);

  /// The scope this router reads and writes through.
  final Ref ref;

  /// Follows [href], written in whichever document is active.
  Future<LinkOutcome> follow(String href) async {
    final active = ref.read(activeDocumentProvider);
    final documentPath = active.doc?.path ?? active.file?.path ?? '';
    final files = ref.read(fileServiceProvider);

    final target = classifyLink(
      href: href,
      documentPath: documentPath,
      registry: files.registry,
    );

    return switch (target) {
      AnchorLink(:final slug) => _anchor(slug),
      DocumentLink(:final path, :final anchor) => _document(path, anchor),
      ExternalLink(:final uri) => _external(uri),
      UnsupportedLink(:final href, :final scheme) => (
        kind: LinkOutcomeKind.unsupported,
        detail: scheme ?? ExtensionRegistry.basenameOf(href),
      ),
    };
  }

  /// A `#heading` in the document already open.
  LinkOutcome _anchor(String slug) {
    final doc = ref.read(activeDocumentProvider).doc;
    final entry = doc?.outline.bySlug(slug);
    if (entry == null) {
      return (kind: LinkOutcomeKind.missingAnchor, detail: slug);
    }
    // `bySlug` has had no caller since M1. This is it.
    unawaited(ref.read(readerScrollProvider).reveal(entry.blockIndex));
    return (kind: LinkOutcomeKind.anchor, detail: slug);
  }

  /// Another document, optionally at one of its headings.
  LinkOutcome _document(String path, String? anchor) {
    final files = ref.read(fileServiceProvider);
    final file = files.describe(path);
    if (file == null) {
      return (
        kind: LinkOutcomeKind.missingTarget,
        detail: ExtensionRegistry.basenameOf(path),
      );
    }

    // A link into the document already showing is an anchor jump wearing a
    // path. It has to be handled as one: the reader only adopts a document
    // when the document changes, so a pending jump would never be consumed.
    if (file.identity == ref.read(openSetProvider).activeIdentity) {
      return anchor == null
          ? (kind: LinkOutcomeKind.document, detail: file.name)
          : _anchor(anchor);
    }

    ref.read(openSetProvider.notifier).openPaths(<String>[path]);
    if (anchor == null) {
      return (kind: LinkOutcomeKind.document, detail: file.name);
    }

    // The open set has activated it, so the active-document provider will
    // parse it on this read — which is what makes the outline available before
    // the reader has built a single block of it.
    final doc = ref.read(activeDocumentProvider).doc;
    final entry = doc?.outline.bySlug(anchor);
    if (entry == null) {
      return (kind: LinkOutcomeKind.missingAnchor, detail: anchor);
    }
    ref
        .read(readerScrollProvider)
        .revealWhenAdopted(file.identity, entry.blockIndex);
    return (kind: LinkOutcomeKind.document, detail: file.name);
  }

  Future<LinkOutcome> _external(Uri uri) async {
    final opened = await ref.read(launcherLinkProvider).open(uri);
    return opened
        ? (kind: LinkOutcomeKind.external, detail: uri.host)
        : (kind: LinkOutcomeKind.launchFailed, detail: uri.host);
  }
}

/// The link-router provider.
final Provider<LinkRouter> linkRouterProvider = Provider<LinkRouter>(
  LinkRouter.new,
);
