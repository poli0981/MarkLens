import 'package:flutter/widgets.dart';
import 'package:marklens/core/models/doc_model.dart';

/// Turns a parsed [DocModel] into widgets.
///
/// This is the **only** seam through which rendering happens (CLAUDE.md
/// rule 6), and this directory is the only place in the codebase that may
/// import a Markdown renderer package. Everything upstream of here is pure
/// Dart, so swapping the S1 winner touches implementations of this interface
/// and nothing else — see `docs/02_ARCHITECTURE.md`, "The seam".
///
/// Implementations must not throw: a render failure degrades to the plain-text
/// view with a notice bar (CLAUDE.md rule 9).
abstract class MarkdownRenderer {
  /// Builds the reader body for [doc].
  ///
  /// Styling comes from the ambient theme (`docs/06_UI_UX.md`), so that a
  /// renderer swap cannot quietly change the app's typography.
  Widget build(BuildContext context, DocModel doc);
}
