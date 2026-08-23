# S1c — Syntax highlighter

**Status:** complete — `highlight 0.7.0`, used directly
**Branch:** `spike/s1c-highlighter`
**Machine:** Windows 11, Flutter 3.47.1 / Dart 3.13.1
**Date:** 2026-08-23

The last open piece of S1. Doc 01 listed three candidates and flagged the
incumbent as the most fragile pin in the table.

## `syntax_highlight` is out, on two independent grounds

1. **0.5.0 cannot resolve against our stack at all.** It pulls
   `super_native_extensions` → `device_info_plus`, which needs `win32 <6.0.0`,
   while `file_picker 12` holds us at `package_info_plus 10.2.1`, which needs
   `win32 ^6.0.1`. The same win32 chain doc 01 already records.
2. **0.4.0 — the version that does resolve — ships five grammars:** dart, json,
   sql, yaml and serverpod_protocol. A Markdown viewer opens repositories, not
   Serverpod projects.

Either alone would be disqualifying. Note doc 01's earlier concern — that it
drags in `super_clipboard` and a Rust build step — turned out not to apply to
0.4.0; it is ruled out for entirely different reasons.

## `highlight 0.7.0` versus `re_highlight 0.0.3`

The whole reason to consider `re_highlight` was fresher grammars: it tracks
highlight.js v11.9.0, where `highlight 0.7.0` is frozen around 2020. **That
premise did not survive measurement.**

| | `highlight 0.7.0` | `re_highlight 0.0.3` |
|---|---|---|
| Dart 3 sample (records, patterns, `sealed`) | `built_in, class, keyword, number, string, title` | **identical** |
| `sealed` / `base` / `interface` / `mixin` class | `{class, keyword, title}` | **identical** |
| grammars | 190 | 197 |
| aliases js, ts, py, sh, yml, html, c#, md | all resolve | all resolve |
| `toml` alias | ✗ | ✓ |
| **unknown language** | passes the code through unstyled | **throws `AssertionError`** |
| tokenising 13 KB across 5 languages | **16.7 ms** | 24.7 ms |
| Flutter coupling | none — pure Dart, one dependency (`collection`) | imports `flutter/rendering` |
| licence | MIT | MIT |
| publisher | unverified uploader | verified (Reqable.com) |
| last release | 5 years ago | 2 years ago |

With grammar freshness off the table, what remains favours the incumbent:

- **Unknown languages degrade for free.** `highlight.parse` with an unrecognised
  language returns the code intact with no scopes — measured: 47 of 47
  characters through, zero scopes. That *is* the `CodeHighlighter` contract, and
  it satisfies CLAUDE.md rule 9 without us writing anything. `re_highlight`
  raises a hard `AssertionError`, which is document content crashing the
  renderer unless we maintain a language-allowlist guard around every call.
- **It is about 1.5× faster** on the same input.
- **It will still compile in five years.** This is the argument that actually
  decides a long-lived dependency: a pure-Dart package with a single dependency
  has almost nothing to break against, while one tracking Flutter's `rendering`
  API has to keep up with it. "Two years old" is only better than "five years
  old" if the thing is still moving, and neither is.

## Decision

**`highlight 0.7.0`, used directly. `flutter_highlight` is dropped.**

The widget wrapper is precisely the part we do not need: the `CodeHighlighter`
seam returns `List<InlineSpan>`, not a widget. Its only other contribution was
90 bundled themes, and a scope → `TextStyle` map derived from our own doc 06
tokens will be more consistent than importing someone's GitHub theme — doc 13
prefers fifty lines of our own code over a utility dependency.

Net effect on the dependency table: one package removed, and the remaining one
is pure Dart.

`lib/features/reader/rendering/highlight_js_code_highlighter.dart` implements
the seam; `test/features/code_highlighter_test.dart` holds the contract,
including that adversarial input (unterminated strings, unbalanced braces,
replacement characters, a 20,000-character line) never throws.

## Accepted gaps, written down

Doc 15 asks for these explicitly:

- **No `toml`.** A fence labelled `toml` renders unstyled. `ini` is the near
  equivalent and does work. This is the one alias `re_highlight` had and we do
  not.
- **Grammars frozen around 2020.** Languages added to highlight.js since then —
  `wasm`, `wren`, `nestedtext`, the REPL variants — are absent. Measured as no
  practical loss for Dart 3, which is the language this project's own documents
  are full of.
- **Unverified uploader**, on both `highlight` and the `flutter_highlight` we
  are dropping. Not fixable by choosing differently: it is the same uploader.
  Mitigated by what the package *is* — a tokeniser with one dependency and no
  platform code, whose blast radius is the colour of some text.

Revisit if a maintained highlight.js port with a verified publisher appears, or
if `toml` in fenced blocks turns out to matter in daily use.
