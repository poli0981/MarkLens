# 07 · Files & watching

## Extension registry

Default: `md, mdx, markdown, mdown, mkd, mkdn, mdwn` — case-insensitive,
user-editable in Settings (doc 05). The registry gates folder scans, the
file dialog filter, drag-drop, and CLI args alike. Unknown extensions passed
explicitly via CLI open in plain-text view with a notice (user intent wins,
rendering doesn't).

## Folder scan

- Breadth-first from each root; hidden entries (`.`-prefixed, and
  hidden-attribute on Windows) skipped; **symlinked directories skipped**
  (cycle safety) — symlinked files followed.
- Natural sort within each directory (`2.md` < `10.md`), directories first.
- Running total across all roots checked against `files.fileCap`
  (default 1,000, soft): on exceed → dialog "Open first N / Cancel". Never
  silently truncate.
- Scan runs in an isolate for big trees; sidebar streams in results.

## Identity & missing files

Canonical absolute path is the identity (dedupe on open). A file that
disappears keeps its entry with a `missing` badge; if it reappears (watch
event or focus sweep), the badge clears and mtime is re-read. Entries leave
the session only when the user closes them.

## Change detection

`mtime + size` tuple per entry, refreshed on watch events and on the
window-focus sweep (doc 03). The rendered-doc cache key includes mtime, so
staleness is structural, not best-effort.

## Watcher

- Package `watcher`: one directory watcher per open root, individual file
  watchers for ad-hoc files.
- Debounce 200 ms per path; events collapse to a single classification.
- **Editor atomic saves are the hard case** (Spike S5): VS Code and friends
  write temp-then-rename, which surfaces as delete+create or rename pairs.
  WatchService normalizes any sequence ending with the path existing into
  `changed`, and only reports `missing` when the path stays gone past the
  debounce window.
- Watching off (setting) or watcher failure → degrade to the focus-sweep
  path + per-tab `stale` badge. Never a hard error.

## Encoding & size

UTF-8 with BOM stripping; lossy fallback with notice (doc 04). Size ladder:
> 10 MB banner, > 50 MB refuse (doc 04). Zero-byte files render as an empty
document, not an error.
