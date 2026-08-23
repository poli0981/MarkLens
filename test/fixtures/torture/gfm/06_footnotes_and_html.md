# Footnotes and HTML policy

## Footnotes

A statement needing a citation.[^1] Another one.[^longer-label]

Inline reference reused twice.[^1]

[^1]: The first footnote.
[^longer-label]: A footnote with **formatting**, `code`, and a second
    paragraph indented beneath it.

A footnote reference with no definition.[^orphan]

## HTML policy

MarkLens renders no HTML at all (docs/04). Inline HTML must appear as escaped
literal text: <br>, <kbd>Ctrl</kbd>, <em>not emphasis</em>, <b>not bold</b>.

Block HTML must collapse into a "Raw HTML (not rendered)" box:

<div class="callout">
  <p>This paragraph is inside block HTML.</p>
  <script>alert('this must never run');</script>
</div>

<details>
<summary>A details element</summary>

Markdown inside an HTML block.

</details>

An HTML comment: <!-- this should not appear as rendered content -->

A self-closing tag: <img src="https://example.com/tracker.gif" />

An unterminated HTML block:

<div>
still inside the div at end of file
