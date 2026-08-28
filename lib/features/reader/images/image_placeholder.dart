import 'package:flutter/material.dart';
import 'package:marklens/app/theme/reader_tokens.dart';

/// The box shown in place of an image the reader is not displaying.
///
/// One shape for all five reasons — blocked, missing, oversize, unsupported,
/// undecodable — because they are one thing to a reader: *there was a picture
/// here and it is not showing*. Only the words differ, and each set of words
/// says which of the five it was, because a placeholder that will not say why
/// is worse than no placeholder at all.
///
/// It carries the alt text when the document supplied one. That is the only
/// part of the image a reader can still get.
class ImagePlaceholder extends StatelessWidget {
  /// Creates a placeholder.
  const ImagePlaceholder({
    required this.icon,
    required this.message,
    this.detail,
    this.alt,
    this.action,
    super.key,
  });

  /// What kind of not-showing this is.
  final IconData icon;

  /// The translated explanation.
  final String message;

  /// A path, URL or extension — untranslated, because it came from the
  /// document.
  final String? detail;

  /// The document's alt text, if it wrote one.
  final String? alt;

  /// An affordance, such as "load anyway".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(color: tokens.fgMuted);

    return Semantics(
      // `container: true` is load-bearing. Without it the annotation merges
      // with the text inside, and the node's label becomes the label *plus*
      // every line of the box — so a screen reader reads the explanation twice
      // and nothing can find the alt text by name.
      container: true,
      image: true,
      label: alt ?? message,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.bgAlt,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18, color: tokens.fgMuted),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(message, style: label),
                  if (detail != null && detail!.isNotEmpty)
                    Text(
                      detail!,
                      style: label?.copyWith(fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (alt != null && alt!.isNotEmpty)
                    Text(alt!, style: label, maxLines: 2),
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 4),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
