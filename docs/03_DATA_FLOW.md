# 03 · Data flow

## Cold start

```
main()
 ├─ parse CLI args (files/folders)
 ├─ SingleInstance.acquire()
 │    └─ already running? → forward args over localhost socket → exit(0)
 ├─ SettingsStore.load()          # settings.json (or defaults)
 ├─ SessionStore.load()           # session.json (or empty)
 ├─ FileService.validate(session.files)   # mark missing, keep entries
 ├─ merge CLI args into open set (activate first arg)
 ├─ window_manager.restore(geometry)
 └─ runApp
      ├─ sidebar renders from METADATA ONLY (no parsing)
      ├─ active tab → MarkdownPipeline.parse → render
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
  DocCache.hit(path, mtime)? → render cached
  else read bytes → MarkdownPipeline:
       decode UTF-8 (BOM-aware; lossy + notice on invalid)
    → FrontMatterSplitter          # leading --- block → panel model
    → if .mdx: MdxSanitizer        # doc 04 placeholder transform
    → MarkdownRenderer.parse       # AST/widgets + outline extraction
    → DocCache.put (LRU evict > 40)
  restore scroll (session ratio) → render
```

## Watch → reload

```
fs event → debounce 200 ms → classify:
  modified (incl. editor atomic save seen as delete+create or rename):
      invalidate cache entry
      if active tab → re-parse; keep position by nearest-heading anchor,
                      falling back to scroll ratio
      else → mark tab "stale" (re-parse on next activation)
  deleted/renamed-away → entry stays, badge "missing"; reappears → badge clears
window focus regained → cheap mtime sweep over open set (covers watcher gaps)
```

## Session save

```
triggers: tab open/close/switch · scroll settle (≥ 400 ms idle) ·
          window move/resize end · pin/unpin · app exit
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
  → GET api.github.com/repos/poli0981/marklens/releases/latest
  → semver(tag) > semver(self) → passive banner → click opens release page
network failure → silent (log ring buffer only)
```

## State model (Riverpod providers, wired in app/providers.dart)

`settings` · `session` · `openFiles` (ordered entries + missing flags) ·
`activeDoc` (path + parsed DocModel) · `docCache` · `outline(activeDoc)` ·
`watchEvents` (stream) · `findState` (in-file) · `crossSearchState` ·
`updateBanner`.
