# 02 · Architecture

## Layers

```
┌────────────────────────────────────────────────┐
│ app/        shell, menu bar, shortcuts, theme, │
│             provider wiring (composition root) │
├────────────────────────────────────────────────┤
│ features/   sidebar · tabs · reader · outline  │
│             search · status · settings_ui      │
│             about                              │
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
    open_set.dart            # which documents are open, active, pinned
    documents.dart           # the active document, parsed on activation
    session_link.dart        # session.json <-> the running app
    settings_link.dart       # settings.json <-> the running app, debounced
    reader_scroll.dart       # BlockScroller: the reader's position, addressed
                             #   by block index — needs Flutter, and every
                             #   feature that jumps needs it, so it lives here
    find.dart                # find-in-file state (doc 08)
    watch_coordinator.dart   # watch events -> open-set changes
    window_link.dart         # the seam over window_manager, stubbed in tests
    watch_link.dart          # the seam over the watcher, stubbed in tests
    open_files.dart          # the seam over file_picker, stubbed in tests
    theme/                   # tokens, light/dark ThemeData
  core/                      # PURE DART — no package:flutter, ever (rule 3)
    models/                  # OpenedFile, OpenSet, DocModel, Outline,
                             # SessionState, AppSettings, WatchEvent, SearchHit
    files/
      file_service.dart      # breadth-first scan, soft cap, identity, the
                             #   mtime+size tuple; read-only throughout
      extension_registry.dart # which files are ours, and basename/extension
      natural_sort.dart      # 2.md before 10.md, and a total order
    markdown/
      pipeline.dart          # decode → FrontMatterSplitter → MdxSanitizer
                             #   → RawBlockRewriter → parse → DocModel
                             #   (stops *before* widgets)
      markdown_flavor.dart   # the one ExtensionSet, read by core AND by the
                             #   renderer — a divergence here breaks every
                             #   anchor and every search hit
      front_matter.dart      # leading --- block → panel model
      mdx_sanitizer.dart     # tolerant JSX → placeholder transform (doc 04)
      jsx_scanner.dart       # the lexical half of it: where a tag ends and
                             #   where a region closes. Bounded and
                             #   non-recursive, because .mdx is untrusted
      raw_block_rewriter.dart # block HTML → inert fenced block (doc 04)
      recording_syntaxes.dart # position-recording subclasses of markdown's
                             #   own block syntaxes; how the index gets the
                             #   source ranges the AST does not carry
      source_lines.dart      # line offsets, shared by the stages above
      slug.dart              # GitHub heading-slug algorithm (doc 04)
      block_index.dart       # top-level blocks, 1:1 with renderer children
      outline_builder.dart   # headings → Outline, slugged
    storage/json_store.dart       # the one atomic write: temp, flush, rename
    session/session_store.dart    # both stores take the config Directory as a
    settings/settings_store.dart  #   ctor argument — never call path_provider
    watch/watch_service.dart
    search/search_service.dart   # isolate-backed cross-file search
    update/update_service.dart   # GitHub Releases tag check (dart:io HttpClient)
    cache/doc_cache.dart         # LRU of parsed DocModels — never widgets
    cli/launch_arguments.dart    # paths, --help, --version; never throws
    single_instance.dart         # lock file + loopback socket arg-forwarding
  features/
    sidebar/  tabs/  outline/  search/  status/  settings_ui/  about/
    reader/
      rendering/
        markdown_renderer.dart  # abstract MarkdownRenderer (S1 winner behind it)
        code_highlighter.dart   # abstract CodeHighlighter (S1 decision)
  l10n/                      # app_en.arb  app_vi.arb  app_ja.arb
test/
  core/  features/  fixtures/torture/
  architecture/              # core_purity · feature_isolation
                             # no_write · no_network
```

## Boundary rules (enforced by `test/architecture/`)

| From | May import | Never imports |
|---|---|---|
| `core/` | `dart:*`, pure-Dart packages only (`markdown`, `watcher`, `args`, `meta`, `path`, `riverpod`) | `package:flutter`, any Flutter plugin, `app/`, `features/` |
| `features/X` | `core/`, `app/providers.dart`, `app/theme/reader_tokens.dart`, Flutter | any other `features/Y` directly |
| `features/reader/rendering/` | additionally: the S1 renderer package + the highlighter package | — (and nothing else may import those two) |
| `app/` | everything | — |

Cross-feature communication goes through providers declared in
`app/providers.dart` only. This keeps sidebar/tabs/reader decoupled and makes
each feature testable alone.

**This is also why some widget-layer state lives in `app/` rather than in the
feature that looks like it owns it.** `BlockScroller` is the clear case: it
needs Flutter, so `core/` is closed to it (rule 3), but the outline panel and
the find bar both drive it and neither may import `features/reader/`. Same for
`WatchCoordinator`, which is cross-cutting wiring rather than any feature's
business. The test is not "where does this feel like it belongs" but "how many
features need it" — more than one means `app/`, re-exported from
`providers.dart`.

The `core/` row is an **allowlist**, not a denylist: `core_purity_test.dart`
fails on any import that is not explicitly permitted, so a newly added package
has to be argued for rather than silently inherited.

## The seam: why the renderer is not in `core/`

Rule 3 (core is pure Dart) and rule 6 (one renderer interface) used to point at
the same directory, which cannot work — every Markdown renderer package,
`flutter_highlight`, `flutter_svg` and `path_provider` all import
`package:flutter`. Rule 3 wins, because it is the invariant an automated test
can actually hold, and the swappability rule 6 is really after is about having
*one* import site, not about which folder it lives in.

So the pipeline is cut in half:

```
core/markdown/            (pure Dart, unit-testable without a Flutter binding)
  bytes → decode → front-matter split → [mdx sanitize]
        → markdown.Document parse → outline + slugs + block index
        → DocModel { frontMatter, sanitizedSource, blocks, outline, notices,
                     mdxImportsHidden }

features/reader/rendering/   (widget layer — the only place renderer packages exist)
  MarkdownRenderer.build(DocModel, RenderStyle) → Widget
  CodeHighlighter.spans(code, lang)             → List<InlineSpan>
```

**Known, deliberate cost:** the source is parsed twice — once by us for the
outline, heading anchors and search-hit mapping, once by the renderer package
for the widgets. On a 100 KB document that is a few milliseconds against a
150 ms budget (doc 00), and it is exactly what keeps the S1 choice reversible.
Do not "optimise" it away without re-reading this paragraph.

## Key components

- **FileService** — validates paths, scans folders (doc 07), owns the
  extension registry and the 1,000-entry soft cap.
- **MarkdownPipeline** — the only path from bytes to a `DocModel` (doc 04),
  pure Dart end to end. The renderer package is imported *only* inside
  `features/reader/rendering/`.
- **DocCache** — LRU keyed by `identity + mtime + size + settingsRevision`;
  default
  capacity 40 parsed `DocModel`s; invalidated by watch events and by
  parse-affecting setting changes. It caches **parse output, not widgets** —
  Flutter element trees do not survive a tab switch anyway, and parsing is the
  expensive half.
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
the user opened) — `core/log/log_buffer.dart`, built at M3. Help → "Export
diagnostic log" offers it through a save dialog, and that is the only way an
entry ever leaves the process. No log files on disk, ever.

This used to say the export was "the one user-initiated write outside the
config dir". It is not a write of ours at all: `file_picker` 12's `saveFile`
takes the bytes and writes them where the reader pointed, so
`features/about/log_export.dart` encodes and hands over. Doc 10 invariant 5 is
correspondingly stronger, and `no_write_test` lost an allowlist entry rather
than gaining a user.
