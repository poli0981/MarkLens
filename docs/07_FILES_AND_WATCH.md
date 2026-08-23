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

- Package `watcher`: one directory watcher per open root. **Ad-hoc files are
  watched through their parent directory too, never with `FileWatcher`** —
  `File.watch` does not work on Windows, so the package silently falls back to
  polling on a one-second timer. Measured for the same file: 1000 ms via
  `FileWatcher` against 7 ms via the parent directory (spike S5). The cost is
  events for unrelated files in that directory, which the path filter drops.
- Debounce 200 ms per path; events collapse to a single classification. On
  Linux this is required rather than merely tidy: inotify reports content and
  metadata separately, so one save is two `modify` events.
- **Editor atomic saves are the hard case** (Spike S5). Measured on both
  platforms: a temp-then-rename arrives as a plain `modify`, but delete+recreate
  and vim's rename-away-then-rewrite really do arrive as `remove` followed by
  `add`, 22–29 ms apart.

  The first event of that pair is byte-identical to a real deletion, so nothing
  can be decided from the event kinds. **When a path's debounce window closes,
  classify by whether the path exists** — present is `changed`, absent is
  `missing`. That one rule covers every observed sequence, and is why no false
  `missing` badge can flash during an atomic save.

  Full event tables: `docs/spike-results/S5-watcher.md`.
- Watching off (setting) or watcher failure → degrade to the focus-sweep
  path + per-tab `stale` badge. Never a hard error.

## Encoding & size

UTF-8 with BOM stripping; lossy fallback with notice (doc 04). Size ladder:
> 10 MB banner, > 50 MB refuse (doc 04). Zero-byte files render as an empty
document, not an error.
