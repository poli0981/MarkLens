import 'package:marklens/core/models/doc_model.dart';

/// The result of lifting a leading `---` block off a document.
typedef FrontMatterSplit = ({String body, FrontMatter? frontMatter});

/// Separates a document's leading `---` front-matter block from its body.
///
/// Front-matter is never fed to the renderer; it is shown as a collapsible
/// key/value panel instead (`docs/04_MARKDOWN_PIPELINE.md`). YAML that is not
/// simple `key: value` lines is kept and shown raw — never fatal.
///
/// **Not implemented yet** (M2, doc 15). The pass-through below is a
/// placeholder: it reports no front-matter, which is the safe answer while
/// the real splitter does not exist.
class FrontMatterSplitter {
  /// Creates a splitter.
  const FrontMatterSplitter();

  /// Splits [source] into its front-matter block and its body.
  FrontMatterSplit split(String source) => (body: source, frontMatter: null);
}
