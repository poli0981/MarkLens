import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marklens/core/files/extension_registry.dart';
import 'package:marklens/core/images/image_source.dart';
import 'package:marklens/features/reader/images/image_placeholder.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Everything the reader needs to decide what an image is allowed to be
/// (`docs/04_MARKDOWN_PIPELINE.md`, "Images").
///
/// Handed to the renderer, which calls [build] from its `imageBuilder`. It
/// exists because the renderer package is given a `Uri` and nothing else, while
/// the policy needs two things it cannot know: which document the reference was
/// written in, and whether the reader has turned remote images on.
class ImagePolicy {
  /// Creates a policy for one document.
  const ImagePolicy({
    required this.documentPath,
    this.allowRemote = false,
    this.maxBytes = maxImageBytes,
  });

  /// The document the `src` was written in, for resolving relative paths.
  final String documentPath;

  /// `network.allowRemoteImages` (`docs/05_SESSION_AND_SETTINGS.md`), **off by
  /// default**.
  final bool allowRemote;

  /// Above this, a local image needs a click (`docs/04`).
  final int maxBytes;

  /// The widget for [uri], as the renderer's `imageBuilder` wants it.
  Widget build(Uri uri, String? alt) => DocumentImage(
    source: classifyImage(src: uri.toString(), documentPath: documentPath),
    alt: alt,
    allowRemote: allowRemote,
    maxBytes: maxBytes,
  );
}

/// One image in a rendered document, or the placeholder standing in for it.
///
/// The existence and size checks happen **once**, in `initState`, rather than
/// in the classifier. `imageBuilder` is called on every rebuild, and a
/// `ListView` rebuilds its children as they scroll; a `statSync` per image per
/// frame is the sort of thing that is invisible in a test and audible in a
/// 1 MB document.
class DocumentImage extends StatefulWidget {
  /// Creates an image.
  const DocumentImage({
    required this.source,
    required this.allowRemote,
    this.alt,
    this.maxBytes = maxImageBytes,
    super.key,
  });

  /// What the document asked for.
  final ImageSource source;

  /// The document's alt text.
  final String? alt;

  /// Whether `http(s)` images may load.
  final bool allowRemote;

  /// The size above which a local image waits for a click.
  final int maxBytes;

  @override
  State<DocumentImage> createState() => _DocumentImageState();
}

class _DocumentImageState extends State<DocumentImage> {
  /// Size in bytes, or `null` when the file is not there.
  int? _size;

  /// Set by "load anyway", which is why the size guard is an affordance rather
  /// than a refusal: it is still local, and still the reader's decision
  /// (`docs/04_MARKDOWN_PIPELINE.md`).
  bool _loadAnyway = false;

  /// Set when a decoder gave up on the bytes.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _stat();
  }

  @override
  void didUpdateWidget(DocumentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.source;
    final after = widget.source;
    if (before is LocalImageSource &&
        after is LocalImageSource &&
        before.path == after.path) {
      return;
    }
    _loadAnyway = false;
    _failed = false;
    _stat();
  }

  void _stat() {
    final source = widget.source;
    if (source is! LocalImageSource) {
      _size = null;
      return;
    }
    // Rule 9 the ordinary way: a path a document supplied may be a directory,
    // a device, or 4,000 characters of nonsense. Not existing is an answer;
    // throwing is not.
    try {
      final stat = File(source.path).statSync();
      _size = stat.type == FileSystemEntityType.file ? stat.size : null;
    } on FileSystemException {
      _size = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = widget.source;

    if (_failed) {
      return ImagePlaceholder(
        icon: Icons.broken_image_outlined,
        message: l10n.readerImageFailed,
        alt: widget.alt,
      );
    }

    return switch (source) {
      UnsupportedImageSource(:final reason) => ImagePlaceholder(
        icon: Icons.help_outline,
        message: l10n.readerImageUnsupported,
        detail: reason,
        alt: widget.alt,
      ),
      RemoteImageSource(:final uri) => _remote(l10n, uri, isSvg: source.isSvg),
      LocalImageSource(:final path) => _local(l10n, path, isSvg: source.isSvg),
    };
  }

  Widget _remote(AppLocalizations l10n, Uri uri, {required bool isSvg}) {
    if (!widget.allowRemote) {
      // No per-image "allow once" in v1: the zero-network default has to stay
      // legible, and a document that can talk you into one exception can talk
      // you into forty (`docs/04_MARKDOWN_PIPELINE.md`).
      return ImagePlaceholder(
        icon: Icons.cloud_off_outlined,
        message: l10n.readerImageRemoteBlocked,
        detail: uri.toString(),
        alt: widget.alt,
      );
    }
    // The only network egress in the app besides the update check, and the
    // reason `test/architecture/no_network_test.dart` allowlists exactly this
    // directory (CLAUDE.md rule 5).
    return _frame(
      isSvg
          ? SvgPicture.network(
              uri.toString(),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              semanticsLabel: widget.alt,
            )
          : Image.network(
              uri.toString(),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              semanticLabel: widget.alt,
              errorBuilder: (context, _, _) => _failedPlaceholder(l10n),
            ),
    );
  }

  Widget _local(AppLocalizations l10n, String path, {required bool isSvg}) {
    final size = _size;
    if (size == null) {
      // The *resolved* path, not the `src` the document wrote: a relative link
      // that resolved somewhere unexpected is the bug this placeholder exists
      // to make visible (`docs/04_MARKDOWN_PIPELINE.md`).
      return ImagePlaceholder(
        icon: Icons.image_not_supported_outlined,
        message: l10n.readerImageMissing,
        detail: path,
        alt: widget.alt,
      );
    }

    if (size > widget.maxBytes && !_loadAnyway) {
      return ImagePlaceholder(
        icon: Icons.hourglass_empty,
        message: l10n.readerImageTooLarge(
          ExtensionRegistry.basenameOf(path),
        ),
        alt: widget.alt,
        action: TextButton(
          onPressed: () => setState(() => _loadAnyway = true),
          child: Text(l10n.readerImageLoadAnyway),
        ),
      );
    }

    final file = File(path);
    return _frame(
      isSvg
          ? SvgPicture.file(
              file,
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              semanticsLabel: widget.alt,
            )
          : Image.file(
              file,
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              semanticLabel: widget.alt,
              errorBuilder: (context, _, _) => _failedPlaceholder(l10n),
            ),
    );
  }

  /// Keeps an image inside the reading column.
  ///
  /// `scaleDown` rather than `contain`: it shrinks an image too wide for the
  /// column and leaves a small one at its own size, which is what a reader
  /// expects of a badge sitting in a line of prose.
  Widget _frame(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  Widget _failedPlaceholder(AppLocalizations l10n) => ImagePlaceholder(
    icon: Icons.broken_image_outlined,
    message: l10n.readerImageFailed,
    alt: widget.alt,
  );
}
