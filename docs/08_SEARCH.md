# 08 · Search

Three entry points, one principle: search the *source text*, map hits to
block positions for scrolling.

## Find in file — `Ctrl+F`

Inline bar over the reader: query, case toggle, match counter `3/17`,
Enter / Shift+Enter to cycle, Esc closes. All matches highlighted in the
rendered view; current match gets the accent pulse. Implementation: literal
search over the document source; each hit maps to its block index → scroll +
in-block highlight. Matches inside front-matter and MDX placeholder raw
sections count (they're readable content).

## Search open files — `Ctrl+Shift+F`

Panel replacing the sidebar: query + case toggle, results grouped by file
with per-hit context line, click → open/activate tab and jump. Literal in
v1 (regex toggle is a v1.x candidate).

Execution: `Isolate.run` — the isolate receives the open-set path list,
reads files straight from disk (documents don't need to be parsed or cached
to be searched), scans, and streams grouped hits back. Budget: 1,000 files ×
~10 KB in **< 300 ms** on the reference machine. Cancellation on query
change.

## Quick switcher — `Ctrl+P`

Fuzzy match over open-set names + relative paths + recent list. Subsequence
scoring (word-boundary and path-segment bonuses), top 20, arrows + Enter.
This is the intended navigation for a 1,000-entry session — the tab strip is
for the working few, Ctrl+P is for everything.

## Non-goals

No persistent index, no content search of *unopened* folders, no
search-and-replace (read-only, forever).
