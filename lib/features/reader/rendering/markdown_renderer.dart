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
  ///
  /// [wrapBlock] is called once per `DocModel.blocks` entry, with that entry's
  /// index, and whatever it returns is what the reader shows for that block.
  /// It is how everything outside this directory — the outline's jumps, the
  /// find bar's highlights, the scroll-position measurements — reaches a block
  /// without knowing how the renderer lays them out. Which matters, because
  /// the mapping is not one-to-one: `flutter_markdown_plus` emits `2N-1`
  /// children with a spacer between every pair, and that arithmetic stays
  /// inside the implementation, where it is the only thing that knows it.
  Widget build(BuildContext context, DocModel doc, {BlockWrapper? wrapBlock});
}

/// Wraps one top-level block on its way to the screen.
///
/// [blockIndex] indexes `DocModel.blocks`, never the renderer's child list.
typedef BlockWrapper = Widget Function(int blockIndex, Widget child);
