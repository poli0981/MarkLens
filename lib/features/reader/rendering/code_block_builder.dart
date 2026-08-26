import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:marklens/app/theme/reader_tokens.dart';
import 'package:marklens/core/markdown/raw_block_rewriter.dart';
import 'package:marklens/features/reader/rendering/code_highlighter.dart';
import 'package:marklens/l10n/gen/app_localizations.dart';

/// Draws every `pre` block: fenced code, and the "Raw HTML (not rendered)"
/// box that `RawBlockRewriter` produces upstream.
///
/// Both arrive as the same AST shape — `pre > code` — and are told apart by
/// the metadata the rewriter puts in the fence's info string. That is the
/// whole reason the info string carries two words: the first keeps the body
/// highlighting as HTML, the second says where the block came from
/// (`docs/04_MARKDOWN_PIPELINE.md`).
class CodeBlockBuilder extends MarkdownElementBuilder {
  /// Creates a builder that colours code with [highlighter].
  CodeBlockBuilder({required this.highlighter});

  /// Turns code into spans. An unknown language yields plain spans rather than
  /// an error — that is the seam's contract (`docs/01_TECH_STACK.md`).
  final CodeHighlighter highlighter;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstWhere(
      (child) => child.tag == 'code',
      orElse: () => md.Element.text('code', element.textContent),
    );
    final source = _withoutTrailingNewline(code?.textContent ?? '');
    final language = _languageOf(code);
    final isRawHtml = element.attributes['data-metadata'] == rawBlockMetadata;

    return _CodeBlock(
      source: source,
      language: language,
      isRawHtml: isRawHtml,
      highlighter: highlighter,
    );
  }

  /// The language from `class="language-x"`, or `null` when the fence had none.
  static String? _languageOf(md.Element? code) {
    final className = code?.attributes['class'];
    if (className == null || !className.startsWith('language-')) {
      return null;
    }
    final language = className.substring('language-'.length);
    return language.isEmpty ? null : language;
  }

  /// The parser adds a final newline to fenced content; showing it would put an
  /// empty line at the bottom of every code block.
  static String _withoutTrailingNewline(String code) =>
      code.endsWith('\n') ? code.substring(0, code.length - 1) : code;
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.source,
    required this.language,
    required this.isRawHtml,
    required this.highlighter,
  });

  final String source;
  final String? language;
  final bool isRawHtml;
  final CodeHighlighter highlighter;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  /// Raw HTML opens collapsed — doc 04 calls it a collapsed box, and the point
  /// of it is to say "there was something here", not to show it by default.
  late bool _expanded = !widget.isRawHtml;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.source));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final label = widget.isRawHtml
        ? l10n.readerRawHtmlTitle
        : (widget.language ?? '');

    return Container(
      decoration: BoxDecoration(
        color: tokens.codeBg,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(
            label: label,
            expanded: _expanded,
            copied: _copied,
            // Only the raw-HTML box is collapsible. A code block the author
            // wrote is content, and hiding content behind a click is not a
            // reader's job.
            onToggle: widget.isRawHtml
                ? () => setState(() => _expanded = !_expanded)
                : null,
            onCopy: _copy,
          ),
          if (_expanded)
            _Body(
              source: widget.source,
              language: widget.language,
              highlighter: widget.highlighter,
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.expanded,
    required this.copied,
    required this.onToggle,
    required this.onCopy,
  });

  final String label;
  final bool expanded;
  final bool copied;
  final VoidCallback? onToggle;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: <Widget>[
          if (onToggle != null)
            IconButton(
              onPressed: onToggle,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              tooltip: expanded ? l10n.readerCollapse : l10n.readerExpand,
              icon: Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                color: tokens.fgMuted,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tokens.fgMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onCopy,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: copied ? l10n.readerCopied : l10n.readerCopyCodeTooltip,
            icon: Icon(
              copied ? Icons.check : Icons.copy_outlined,
              color: copied ? tokens.accent : tokens.fgMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.source,
    required this.language,
    required this.highlighter,
  });

  final String source;
  final String? language;
  final CodeHighlighter highlighter;

  @override
  Widget build(BuildContext context) {
    final tokens = ReaderTokens.of(context);

    return Scrollbar(
      // Long lines scroll rather than wrap: wrapping code changes what it
      // says (`docs/06_UI_UX.md`).
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        // Deliberately no SelectionArea of its own. The reader wraps the whole
        // document in one, and a nested scope would end a drag at the top of
        // the code block — which is exactly what S2 made a release gate
        // (`docs/spike-results/S2-selection.md`).
        child: Text.rich(
          TextSpan(
            children: highlighter.spans(code: source, language: language),
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const <String>['Courier New', 'monospace'],
              fontSize: 13,
              height: 1.45,
              color: tokens.fg,
            ),
          ),
        ),
      ),
    );
  }
}
