import 'package:marklens/core/markdown/jsx_scanner.dart';
import 'package:marklens/core/markdown/raw_block_rewriter.dart';
import 'package:marklens/core/markdown/source_lines.dart';
import 'package:marklens/core/models/doc_model.dart';

/// The marker that tells the reader a `pre` block is an MDX component
/// placeholder rather than code the author wrote.
///
/// It arrives as `pre.attributes['data-metadata']`, exactly as
/// [rawBlockMetadata] does, followed by the component name and its attribute
/// names — see [mdxPlaceholderOf].
const String mdxPlaceholderMetadata = 'marklens-mdx';

/// The language a placeholder card's body is highlighted as.
const String mdxPlaceholderLanguage = 'jsx';

/// The language doc 04 gives a bailed-out region: "emitted as a fenced code
/// block labelled `mdx`".
const String mdxBailOutLanguage = 'mdx';

/// The floor on how far one document may be scanned looking for closing tags,
/// on top of a multiple of its own length.
///
/// See [MdxSanitizer.sanitize]: without a *shared* budget, each unclosed
/// component costs its own scan, and a document that is nothing but unclosed
/// components is quadratic — measured at 117 ms / 396 ms / 1557 ms for 2,500 /
/// 5,000 / 10,000 of them, which is four times the work for twice the input.
/// The per-region `spanLimit` does not help: it only engages above 64 KB, and
/// the document that showed this was 60 KB.
const int mdxMinimumScanBudget = 64 * 1024;

/// How much of the document one region scan may cover before it gives up.
const int mdxRegionSpanLimit = 64 * 1024;

/// How many attribute names a placeholder card summarises before stopping.
///
/// The summary rides the fence's info string, which is one line; a component
/// with forty attributes would push the card's header past anything readable
/// long before it pushed the info string past anything workable.
const int mdxSummaryAttributeLimit = 8;

/// The result of transforming MDX into inert Markdown.
typedef MdxSanitizeResult = ({
  String source,
  List<DocNotice> notices,
  int esmRemoved,
});

/// What a placeholder fence says about the component it replaced.
class MdxPlaceholder {
  /// Creates a placeholder description.
  const MdxPlaceholder({required this.name, required this.attributes});

  /// The component's name, dots included.
  final String name;

  /// Its attribute names, in source order, capped at
  /// [mdxSummaryAttributeLimit].
  final List<String> attributes;
}

/// Reads a fence's `data-metadata` back into a [MdxPlaceholder], or returns
/// `null` when the fence is not one of ours.
///
/// The reader calls this. Keeping the encoding and the decoding in one file is
/// the same discipline [rawBlockFenceInfo] follows: a writer and a reader that
/// live apart drift apart.
MdxPlaceholder? mdxPlaceholderOf(String? metadata) {
  if (metadata == null) {
    return null;
  }
  final words = metadata.split(' ').where((word) => word.isNotEmpty).toList();
  if (words.length < 2 || words.first != mdxPlaceholderMetadata) {
    return null;
  }
  return MdxPlaceholder(
    name: words[1],
    attributes: words.sublist(2),
  );
}

/// Rewrites `.mdx` source so its structure is readable and nothing can run.
///
/// A tolerant scanner, deliberately not a JSX parser: ESM lines are dropped,
/// block-level components become placeholder cards, inline components become
/// chips, and anything it cannot classify is emitted as a fenced `mdx` code
/// block. Bailing out is correct behaviour, not an error — see the placeholder
/// spec in `docs/04_MARKDOWN_PIPELINE.md`.
///
/// **It is a source-to-source rewrite**, like [RawBlockRewriter], and for the
/// same reason: `core/markdown/` is pure Dart and ends at a string, so every
/// one of doc 04's five transforms has to be expressible as inert Markdown.
/// Four of them are fences or code spans; the fifth — the count of hidden ESM
/// statements, which the header chip shows — is the one thing a string cannot
/// carry, so it leaves through [MdxSanitizeResult] instead.
///
/// **It runs before [RawBlockRewriter]** (`docs/03_DATA_FLOW.md`). By the time
/// the rewriter sees the document, every capitalized or dotted block tag is
/// already a fence, and what is left for it is genuine lowercase HTML. That is
/// a change from M1, where the rewriter rescued component tags incidentally —
/// they are HTML blocks by CommonMark start condition 7 — and doc 04 is
/// amended to say so.
class MdxSanitizer {
  /// Creates a sanitizer.
  const MdxSanitizer({
    this.nestingLimit = 20,
    this.esmStatementLineLimit = 100,
  });

  /// Nesting deeper than this bails out (doc 04, transform 5).
  final int nestingLimit;

  /// How many lines one ESM statement may span before the sanitizer decides it
  /// is not looking at an ESM statement after all and leaves the text alone.
  final int esmStatementLineLimit;

  /// Transforms MDX [source] into Markdown containing only inert constructs.
  ///
  /// Never throws. A construct this scanner cannot classify becomes a fenced
  /// block and a notice; text it has no rule for is copied through byte for
  /// byte, which is why a document with no JSX in it comes back identical.
  MdxSanitizeResult sanitize(String source) {
    if (source.isEmpty) {
      return (source: source, notices: const <DocNotice>[], esmRemoved: 0);
    }

    final lines = SourceLines.of(source);
    final out = StringBuffer();
    var pending = 0;
    var esmRemoved = 0;
    var bailedOut = false;

    _FenceState? fence;
    var paragraphOpen = false;
    var i = 0;

    // Every failed search for a closing tag draws on **one budget for the whole
    // document**, rather than each getting its own. Four times the source plus
    // a floor: a document's legitimate regions never overlap, so scanning them
    // all costs the source once and this is generous for the rest. What it
    // buys is that a file made of nothing but unclosed components is linear
    // rather than quadratic — and when the budget runs out, the remaining
    // regions bail out to fenced `mdx` blocks, which is what doc 04 says an
    // unbalanced tag becomes anyway. The output does not change; only the time
    // it takes to reach it (CLAUDE.md rule 9, doc 00 principle 3).
    final budget = _ScanBudget(source.length * 4 + mdxMinimumScanBudget);

    while (i < lines.length) {
      final content = lines.contents[i];
      final lineStart = lines.starts[i];

      if (fence != null) {
        if (fence.closedBy(content)) {
          fence = null;
        }
        i++;
        continue;
      }

      final opening = _FenceState.opening(content);
      if (opening != null) {
        fence = opening;
        paragraphOpen = false;
        i++;
        continue;
      }

      if (content.trim().isEmpty) {
        paragraphOpen = false;
        i++;
        continue;
      }

      // An indented code block. Doc 04 only names fenced code and inline code,
      // but `test/fixtures/torture/mdx/fence_with_fake_jsx.mdx` carries an
      // indented one and expects it untouched — and it is right to: four
      // spaces after a blank line is code by CommonMark. The approximation is
      // the "after a blank line" part, which is what keeps this a line scanner
      // rather than a block parser; a lazily indented paragraph continuation
      // reads as code here and is left alone, which is the safe direction.
      if (!paragraphOpen && _indentOf(content) >= 4) {
        i++;
        continue;
      }

      if (_isEsmStart(content)) {
        final span = _esmStatementSpan(lines, i);
        if (span != null) {
          out.write(source.substring(pending, lineStart));
          pending = lines.offsetOfLine(span);
          esmRemoved++;
          paragraphOpen = false;
          i = span;
          continue;
        }
      }

      if (content.codeUnitAt(0) == _lessThan) {
        final block = _blockRegion(lines, i, source, budget);
        if (block != null) {
          out
            ..write(source.substring(pending, lineStart))
            ..write(block.replacement);
          pending = lines.offsetOfLine(block.endLineExclusive);
          bailedOut = bailedOut || block.bailedOut;
          paragraphOpen = false;
          i = block.endLineExclusive;
          continue;
        }
      }

      final transformed = _transformInline(content);
      if (transformed != content) {
        out
          ..write(source.substring(pending, lineStart))
          ..write(transformed);
        pending = lineStart + content.length;
      }
      paragraphOpen = true;
      i++;
    }

    out.write(source.substring(pending));

    return (
      source: out.toString(),
      notices: <DocNotice>[
        if (bailedOut) const DocNotice(DocNoticeKind.mdxBailOut),
      ],
      esmRemoved: esmRemoved,
    );
  }

  /// The block-level region opening on line [index], or `null` when that line
  /// does not start one.
  ///
  /// Returning `null` sends the line down the inline path, which is the right
  /// answer for a lowercase tag (HTML, and [RawBlockRewriter]'s), for a tag
  /// with prose after it on the same line (not block-level), and for a `<`
  /// that opens nothing at all.
  _BlockReplacement? _blockRegion(
    SourceLines lines,
    int index,
    String source,
    _ScanBudget budget,
  ) {
    final start = lines.starts[index];
    final limit = budget.allow(mdxRegionSpanLimit);
    final region = scanJsxRegion(
      source,
      start,
      depthLimit: nestingLimit,
      spanLimit: limit,
    );
    budget.spend(
      region != null && region.balanced ? region.end - start : limit,
    );
    if (region == null) {
      // No tag here at all — or a tag that never terminates, which is doc 04's
      // first bail-out condition rather than something to leave lying around.
      // `<Another attr="value"` at the end of the unterminated fixture is
      // exactly this: it is not an HTML block by any CommonMark start
      // condition, so nothing downstream would rescue it either.
      final name = jsxTagNameAt(source, start);
      if (name != null && isComponentTagName(name)) {
        return _bailOut(lines, index, index + 1);
      }
      return null;
    }
    if (!region.open.isComponent) {
      return null;
    }

    if (!region.balanced) {
      // Doc 04 transform 5, and the reason the fixture says "rather than
      // guessing where it ends": the bail-out covers the opening tag and
      // nothing after it, so the heading and the prose below an unclosed
      // component survive.
      final endLine = _lineContaining(lines, region.open.end - 1, index);
      return _bailOut(lines, index, endLine + 1);
    }

    final endLine = _lineContaining(lines, region.end - 1, index);
    final tail = source.substring(
      region.end,
      lines.starts[endLine] + lines.contents[endLine].length,
    );
    if (tail.trim().isNotEmpty) {
      // `<Foo /> and then prose` is a paragraph containing a component, not a
      // block-level component. The chip is the correct rendering.
      return null;
    }

    if (region.maxDepth > nestingLimit) {
      return _bailOut(lines, index, endLine + 1);
    }

    final body = _linesText(lines, index, endLine + 1);
    final attributes = region.open.attributes
        .take(mdxSummaryAttributeLimit)
        .join(' ');
    final info = <String>[
      mdxPlaceholderLanguage,
      mdxPlaceholderMetadata,
      region.open.name,
      if (attributes.isNotEmpty) attributes,
    ].join(' ');

    return _BlockReplacement(
      replacement: _fence(lines, index, endLine + 1, info, body),
      endLineExclusive: endLine + 1,
      bailedOut: false,
    );
  }

  _BlockReplacement _bailOut(
    SourceLines lines,
    int startLine,
    int endLineExclusive,
  ) => _BlockReplacement(
    replacement: _fence(
      lines,
      startLine,
      endLineExclusive,
      mdxBailOutLanguage,
      _linesText(lines, startLine, endLineExclusive),
    ),
    endLineExclusive: endLineExclusive,
    bailedOut: true,
  );

  /// Wraps [body] in a fence long enough that nothing inside can close it.
  String _fence(
    SourceLines lines,
    int startLine,
    int endLineExclusive,
    String info,
    String body,
  ) {
    final eol = _terminatorOf(lines, endLineExclusive - 1);
    final marker = markdownFenceMarker(body);
    final buffer = StringBuffer()
      ..write(marker)
      ..write(info)
      ..write(eol.isEmpty ? _documentTerminator(lines.source) : eol)
      ..write(body)
      ..write(eol.isEmpty ? _documentTerminator(lines.source) : eol)
      ..write(marker)
      ..write(eol);
    return buffer.toString();
  }

  /// Doc 04 transforms 3 and 4: component tags become chips and braced
  /// expressions become literal code spans, both **outside code spans and
  /// outside link destinations**.
  ///
  /// The link-destination exception is not decoration.
  /// `test/fixtures/torture/mdx/braces_in_links.mdx` has `{id}` inside a link
  /// target, and wrapping that in backticks would not make it literal — it
  /// would break the link.
  String _transformInline(String line) {
    final out = StringBuffer();
    var i = 0;

    while (i < line.length) {
      final unit = line.codeUnitAt(i);

      if (unit == _backtick) {
        final end = _codeSpanEnd(line, i);
        out.write(line.substring(i, end));
        i = end;
        continue;
      }
      if (unit == _closeBracket &&
          i + 1 < line.length &&
          line.codeUnitAt(i + 1) == _openParen) {
        final end = _linkDestinationEnd(line, i + 1);
        out.write(line.substring(i, end));
        i = end;
        continue;
      }
      if (unit == _lessThan) {
        final tag = parseJsxTag(line, i);
        if (tag != null && tag.isComponent) {
          out.write(
            jsxCodeSpan('⟨${tag.closing ? '/' : ''}${tag.name}⟩'),
          );
          i = tag.end;
          continue;
        }
      }
      if (unit == _openBrace) {
        final end = balancedBraceEnd(line, i);
        if (end != null) {
          out.write(jsxCodeSpan(line.substring(i, end)));
          i = end;
          continue;
        }
        // An unbalanced brace is not an expression, so it is not transformed.
        // It already renders as the literal text it is, which is what doc 04
        // asks for; the bail-out is for regions, not for a stray character.
      }

      out.write(line[i]);
      i++;
    }

    return out.toString();
  }

  /// Whether [line] is a top-level ESM statement (doc 04, transform 1).
  ///
  /// Tight on purpose. A paragraph opening with the word "import" is ordinary
  /// prose, and deleting it would be the worst failure this class could have.
  static bool _isEsmStart(String line) {
    if (line.startsWith('import')) {
      return _esmTail(line, 'import', const <String>['{', '*', "'", '"']);
    }
    if (line.startsWith('export')) {
      return _esmTail(line, 'export', const <String>[
        '{',
        '*',
        'default',
        'const',
        'let',
        'var',
        'function',
        'class',
        'async',
      ]);
    }
    return false;
  }

  static bool _esmTail(String line, String keyword, List<String> openers) {
    final rest = line.substring(keyword.length);
    final trimmed = rest.trimLeft();
    if (trimmed.isEmpty) {
      return false;
    }
    final spaced = rest.length != trimmed.length;
    for (final opener in openers) {
      if (trimmed.startsWith(opener)) {
        return true;
      }
    }
    // `import Callout from '…'` — a default import, which needs the space and
    // an identifier, and needs the `from` to distinguish it from prose.
    return spaced && keyword == 'import' && trimmed.contains(' from ');
  }

  /// The line after the ESM statement starting at [index], or `null` when it
  /// does not close within [esmStatementLineLimit] lines.
  int? _esmStatementSpan(SourceLines lines, int index) {
    var depth = 0;
    for (
      var i = index;
      i < lines.length && i - index < esmStatementLineLimit;
      i++
    ) {
      depth = _bracketDepth(lines.contents[i], depth);
      if (depth <= 0) {
        return i + 1;
      }
    }
    return null;
  }

  /// [depth] after [line], counting brackets and skipping quoted runs.
  static int _bracketDepth(String line, int depth) {
    var result = depth;
    var i = 0;
    while (i < line.length) {
      final unit = line.codeUnitAt(i);
      if (unit == _doubleQuote || unit == _singleQuote || unit == _backtick) {
        i = skipQuoted(line, i);
        continue;
      }
      if (unit == _openBrace || unit == _openParen || unit == _openBracket) {
        result++;
      } else if (unit == _closeBrace ||
          unit == _closeParen ||
          unit == _closeBracket) {
        result--;
      }
      i++;
    }
    return result;
  }

  /// The text of lines [start] until [endExclusive], terminators between them
  /// included and the last one excluded.
  static String _linesText(SourceLines lines, int start, int endExclusive) {
    final from = lines.starts[start];
    final last = endExclusive - 1;
    final to = lines.starts[last] + lines.contents[last].length;
    return lines.source.substring(from, to);
  }

  /// The line terminator line [index] ends with, or `''` at end of file.
  static String _terminatorOf(SourceLines lines, int index) {
    final end = lines.starts[index] + lines.contents[index].length;
    return lines.source.substring(end, lines.offsetOfLine(index + 1));
  }

  /// Which line holds [offset], searching forward from [from].
  static int _lineContaining(SourceLines lines, int offset, int from) {
    var i = from;
    while (i + 1 < lines.length && lines.starts[i + 1] <= offset) {
      i++;
    }
    return i;
  }

  /// The terminator for a fence closing a region that runs to the end of a
  /// file with no final newline.
  static String _documentTerminator(String source) =>
      source.contains('\r\n') ? '\r\n' : '\n';

  static int _indentOf(String line) {
    var i = 0;
    while (i < line.length) {
      final unit = line.codeUnitAt(i);
      if (unit == 0x20) {
        i++;
      } else if (unit == 0x09) {
        // A tab is four columns here, which is all this decision needs.
        return 4;
      } else {
        break;
      }
    }
    return i;
  }

  /// The offset one past the code span opening at [start], or one past the
  /// opening run when it never closes.
  static int _codeSpanEnd(String line, int start) {
    var open = 0;
    var i = start;
    while (i < line.length && line.codeUnitAt(i) == _backtick) {
      open++;
      i++;
    }
    var j = i;
    while (j < line.length) {
      if (line.codeUnitAt(j) != _backtick) {
        j++;
        continue;
      }
      var close = 0;
      final runStart = j;
      while (j < line.length && line.codeUnitAt(j) == _backtick) {
        close++;
        j++;
      }
      if (close == open) {
        return j;
      }
      if (runStart == j) {
        j++;
      }
    }
    return i;
  }

  /// The offset one past the `(…)` link destination opening at [start].
  static int _linkDestinationEnd(String line, int start) {
    var depth = 0;
    var i = start;
    while (i < line.length) {
      final unit = line.codeUnitAt(i);
      if (unit == _openParen) {
        depth++;
      } else if (unit == _closeParen) {
        depth--;
        if (depth == 0) {
          return i + 1;
        }
      }
      i++;
    }
    return line.length;
  }
}

/// One document's shared allowance for searching forward.
class _ScanBudget {
  _ScanBudget(this.remaining);

  /// Characters still available. Never negative.
  int remaining;

  /// The most one scan may cover, at most [ceiling].
  int allow(int ceiling) => remaining < ceiling ? remaining : ceiling;

  /// Records [spent], which a caller may overshoot on the last scan.
  void spend(int spent) {
    remaining -= spent;
    if (remaining < 0) {
      remaining = 0;
    }
  }
}

/// One block-level region, rewritten.
class _BlockReplacement {
  const _BlockReplacement({
    required this.replacement,
    required this.endLineExclusive,
    required this.bailedOut,
  });

  final String replacement;
  final int endLineExclusive;
  final bool bailedOut;
}

/// An open fenced code block, so the scanner can leave its contents alone.
class _FenceState {
  const _FenceState(this.marker, this.length);

  /// The fence opened by [line], or `null`.
  static _FenceState? opening(String line) {
    final trimmed = line.trimLeft();
    if (line.length - trimmed.length >= 4 || trimmed.length < 3) {
      return null;
    }
    final marker = trimmed.codeUnitAt(0);
    if (marker != _backtick && marker != _tilde) {
      return null;
    }
    var length = 0;
    while (length < trimmed.length && trimmed.codeUnitAt(length) == marker) {
      length++;
    }
    if (length < 3) {
      return null;
    }
    // A backtick fence's info string may not contain a backtick, which is what
    // makes ``` `a` ``` a code span rather than an unterminated fence.
    if (marker == _backtick && trimmed.substring(length).contains('`')) {
      return null;
    }
    return _FenceState(marker, length);
  }

  final int marker;
  final int length;

  /// Whether [line] closes this fence: the same character, at least as long,
  /// and nothing but whitespace after it.
  bool closedBy(String line) {
    final trimmed = line.trimLeft();
    if (line.length - trimmed.length >= 4) {
      return false;
    }
    var run = 0;
    while (run < trimmed.length && trimmed.codeUnitAt(run) == marker) {
      run++;
    }
    return run >= length && trimmed.substring(run).trim().isEmpty;
  }
}

const int _lessThan = 0x3C;
const int _backtick = 0x60;
const int _tilde = 0x7E;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _openParen = 0x28;
const int _closeParen = 0x29;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _doubleQuote = 0x22;
const int _singleQuote = 0x27;
