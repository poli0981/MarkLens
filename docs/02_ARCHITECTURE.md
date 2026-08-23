# 02 · Architecture

## Layers

```
┌────────────────────────────────────────────────┐
│ app/        shell, menu bar, shortcuts, theme, │
│             provider wiring (composition root) │
├────────────────────────────────────────────────┤
│ features/   sidebar · tabs · reader · outline  │
│             search · settings_ui · about       │
├────────────────────────────────────────────────┤
│ core/       PURE DART services + models        │
│             (no package:flutter imports)       │
└────────────────────────────────────────────────┘
```

## Repo structure (target)

```
lib/
  main.dart                  # CLI args, single-instance, bootstrap, runApp
  app/
    app.dart                 # MaterialApp, theme, shell layout
    providers.dart           # composition root: core services → providers
    menu/                    # menu bar widgets: File / View / Help
    shortcuts.dart           # Intents + Actions bindings (doc 06)
    theme/                   # tokens, light/dark ThemeData
  core/
    models/                  # OpenedFile, DocModel, Outline, SessionState,
                             # AppSettings, WatchEvent, SearchHit
    files/file_service.dart  # open/scan, extension registry, cap, natural sort
    markdown/
      pipeline.dart          # FrontMatterSplitter → MdxSanitizer → renderer
      renderer.dart          # abstract MarkdownRenderer (S1 winner behind it)
      mdx_sanitizer.dart     # tolerant JSX → placeholder transform
    session/session_store.dart
    settings/settings_store.dart
    watch/watch_service.dart
    search/search_service.dart   # isolate-backed cross-file search
    update/update_service.dart   # GitHub Releases tag check
    cache/doc_cache.dart         # LRU of rendered documents
    single_instance.dart         # lock file + localhost socket arg-forwarding
  features/
    sidebar/  tabs/  reader/  outline/  search/  settings_ui/  about/
  l10n/                      # app_en.arb  app_vi.arb  app_ja.arb
test/
  core/  features/  architecture/  fixtures/torture/
```

## Boundary rules (enforced by `test/architecture/`)

| From | May import | Never imports |
|---|---|---|
| `core/` | `dart:*`, pinned pure-Dart packages | `package:flutter`, `app/`, `features/` |
| `features/X` | `core/`, `app/providers.dart`, Flutter | any other `features/Y` directly |
| `app/` | everything | — |

Cross-feature communication goes through providers declared in
`app/providers.dart` only. This keeps sidebar/tabs/reader decoupled and makes
each feature testable alone.

## Key components

- **FileService** — validates paths, scans folders (doc 07), owns the
  extension registry and the 1,000-entry soft cap.
- **MarkdownPipeline** — the only path from bytes to widgets (doc 04). The
  renderer package is imported *only* inside `core/markdown/`.
- **DocCache** — LRU keyed by `path + mtime + settingsRevision`; default
  capacity 40 rendered documents; invalidated by watch events and by
  render-affecting setting changes.
- **SessionStore / SettingsStore** — versioned JSON, atomic writes (doc 05).
- **WatchService** — wraps `watcher`, debounces, normalizes editor
  atomic-save patterns into plain "changed" events (doc 07).
- **SearchService** — reads and scans in an isolate (doc 08).
- **UpdateService** — optional tag check (doc 11).
- **SingleInstance** — lock file in the config dir + localhost socket; a
  second launch forwards its CLI paths to the first and exits (~50 lines,
  no extra dependency).

## Error philosophy

Rule 9 of CLAUDE.md, concretely: every stage of the pipeline catches its own
failures and degrades — bad YAML front-matter renders the raw block in the
panel; an MDX construct the sanitizer can't classify falls back to a code
block; a parser exception yields the plain-text view with a notice bar. The
app process itself must be unkillable by file content.

## Logging

In-memory ring buffer (500 entries, plain structs, no PII beyond file paths
the user opened). Help → "Export diagnostic log" writes a `.log` file via a
save dialog — the one user-initiated write outside the config dir, and it is
user-pointed. No log files on disk otherwise.
