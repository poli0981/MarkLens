# 03 · Data flow

## Cold start

```
main()
 ├─ parse CLI args (files/folders)
 ├─ SingleInstance.acquire()
 │    └─ already running? → forward args over loopback socket → exit(0)
 │       (exit, not return: on Windows the native runner has already made a
 │        window and started its message loop before Dart main runs)
 ├─ SettingsStore.load()          # settings.json (or defaults)
 ├─ SessionStore.load()           # session.json (or empty)
 ├─ FileService.validate(session.files)   # mark missing, keep entries
 ├─ merge CLI args into open set (activate first arg)
 ├─ window_manager.restore(geometry)
 └─ runApp
      ├─ sidebar renders from METADATA ONLY (no parsing)
      ├─ active tab → MarkdownPipeline.parse → DocModel → renderer.build
      └─ WatchService.start(open roots + ad-hoc files)
```

Nothing but the active document is parsed at startup — this is what keeps
1,000 restored entries free.

## Open (dialog / drag-drop / CLI / forwarded args)

```
paths → FileService
  folder? → scan (doc 07: filter, skip symlinked dirs, natural sort)
  cap check → over 1,000 → dialog: open first N / cancel
  → entries appended to open set (dedupe by canonical path)
  → first new entry becomes active tab
```

## Tab activation

```
activate(path)
  DocCache.get(identity, mtime, size)? → reuse the cached DocModel
  else read bytes → MarkdownPipeline (core/, pure Dart):
       decode UTF-8 (BOM-aware; lossy + notice on invalid)
    → FrontMatterSplitter          # leading --- block → panel model
    → if .mdx: MdxSanitizer        # doc 04 placeholder transform
    → markdown parse               # AST → outline + slugs + block index
    → DocModel                     # pure data; the pipeline stops here
    → DocCache.put (LRU evict > 40)
  DocModel → MarkdownRenderer.build (features/reader/rendering) → widgets
  restore scroll (session ratio) → render
```

## Watch → reload

```
fs event → debounce 200 ms → classify BY WHETHER THE PATH NOW EXISTS
                              (never by the event kinds — S5):
  exists (incl. editor atomic save seen as delete+create or rename):
      invalidate cache entry
      if active tab → re-parse; keep position by nearest-heading anchor,
                      falling back to scroll ratio
      else → mark tab "stale" (re-parse on next activation)
  gone → entry stays, badge "missing"; reappears → badge clears
window focus regained → cheap mtime sweep over open set (covers watcher gaps)
```

## Session save

```
triggers: tab open/close/switch · scroll settle (≥ 400 ms idle) ·
          window move/resize end · pin/unpin · app exit

The shell listens to the open set and the chrome as a whole rather than hooking
each trigger, because the cost of a missed hook is a lost session and the cost
of an extra call is nothing — the store coalesces a second of them into one
write.

The scroll trigger is `BlockScroller.onScrollSettled`, wired in the shell. It is
also the first caller `OpenSetController.recordScroll` has ever had:
`SessionDocument.scroll` round-tripped through JSON from M1 onwards with nothing
at either end, so restoring a reading position only started working at M2.
→ debounce 1,000 ms → serialize SessionState
→ write session.json.tmp → fsync → rename over session.json
```

Settings save on change, same atomic pattern, no debounce needed.

## Link click routing (from rendered documents)

```
#anchor                → scroll to heading (GitHub slug rules, doc 04)
relative .md/.mdx      → resolve against current file dir → open in-app
                          (respect cap; missing target → notice)
http / https           → url_launcher → system browser
anything else          → notice "link type not supported" (never shell-out)
```

## Update check (opt-out, doc 11)

```
launch → setting on? → last check > 24 h?
  → GET api.github.com/repos/poli0981/MarkLens/releases/latest
  → semver(tag) > semver(self) → passive banner → click opens release page
network failure → silent (log ring buffer only)
```

## State model (Riverpod providers, wired in app/providers.dart)

`settings` · `session` · `openFiles` (ordered entries + missing flags) ·
`activeDoc` (path + parsed DocModel) · `docCache` · `outline(activeDoc)` ·
`watchEvents` (stream) · `findState` (in-file) · `crossSearchState` ·
`updateBanner`.
