# 07 · Files & watching

## Extension registry

Default: `md, mdx, markdown, mdown, mkd, mkdn, mdwn` — case-insensitive,
user-editable in Settings (doc 05). The registry gates folder scans, the
file dialog filter, drag-drop, and CLI args alike. Unknown extensions passed
explicitly via CLI open in plain-text view with a notice (user intent wins,
rendering doesn't).

## Folder scan

- Breadth-first from each root; hidden entries skipped;
  **symlinked directories skipped** (cycle safety) — symlinked files followed.
  A symlink pointing at nothing, and a directory that cannot be read, are
  skipped rather than raised: one odd entry must not fail a folder.

  **Accepted gap: the Windows hidden attribute is not honoured** — only
  `.`-prefixed names are. `FileStat` exposes mode, type, size and three
  timestamps and nothing about attributes, so reading it would take a `win32`
  dependency, which `core/` may not have (rule 3). In practice the entries this
  misses are `desktop.ini` and similar, which the extension registry already
  drops. Revisit if a real Markdown file with the hidden attribute ever shows
  up in someone's docs folder.
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

`OpenedFile` carries **two** paths, because they answer different questions.
`identity` is `resolveSymbolicLinksSync` — symlinks followed and, on Windows,
the casing the filesystem actually holds — and is what the open set dedupes
on, what the session stores and part of the document cache key. `path` is the
absolute path in its on-disk casing, and is what is shown and opened: a
case-folded path in the sidebar would lower-case the folder names the user
chose.

## Change detection

`mtime + size` tuple per entry, refreshed on watch events and on the
window-focus sweep (doc 03). **The whole tuple is in the parsed-document cache
key**, so staleness is structural, not best-effort — mtime alone would
reintroduce the same-tick rewrite the pair exists to catch. Note "parsed", not
"rendered": the cache holds `DocModel`s and never widgets (rule 8).

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
  path + per-tab `stale` badge. Never a hard error. "Off" means **no watcher is
  started at all**, not a flag consulted downstream; and one directory that
  fails to open leaves every other watcher running.
- The focus sweep is `onWindowFocus` on the shell: `refreshAll()` plus a
  `flush()` of anything still inside its debounce window.

### Accepted gap: a file added to an open root does not join the open set

The watcher hears about it — the root's watcher is recursive — but the
coordinator only acts on paths that are already open, so a new file appears in
the sidebar the next time the folder is opened rather than the moment it is
created. Recorded rather than fixed: doing it properly means re-running the scan
with its cap and its natural sort on every event, and "the folder I opened grew
a file" is not a case the charter's daily workflow leans on. No document claimed
otherwise, so this is a gap being written down rather than a divergence.

### Which piece does what

`WatchService` (pure Dart, `core/watch/`) owns the watchers and the filtering;
`WatchNormalizer` owns the debounce and the classification; `WatchLink` in
`app/` is the test seam, exactly as `WindowLink` is for the window; and
`WatchCoordinator`, also in `app/`, turns a normalized event into a change to
the open set. No feature is involved in any of it — watching is cross-cutting
wiring, and the sidebar, tab strip and reader simply observe the state that
changes. Every badge it raises was already being drawn.

## Encoding & size

UTF-8 with BOM stripping; lossy fallback with notice (doc 04). Size ladder:
> 10 MB banner, > 50 MB refuse (doc 04). Zero-byte files render as an empty
document, not an error.
