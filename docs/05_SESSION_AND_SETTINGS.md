# 05 · Session & settings

## Location

`getApplicationSupportDirectory()/marklens/` →
`session.json`, `settings.json`. These two files are the app's entire disk
footprint besides its installation (rule 1).

`path_provider` is a Flutter plugin, so it is resolved **once** during
bootstrap in `main.dart` and the resulting `Directory` is injected into
`SessionStore` and `SettingsStore` (rule 3 — neither store may import it).
Useful side effect: both stores take a temp directory in tests without any
mocking, which is exactly what doc 12 asks of them.

### What that expands to, and what decides it

| | Path | Decided by |
|---|---|---|
| Windows | `%APPDATA%\poli0981\MarkLens\marklens\` | `CompanyName` and `ProductName` in `windows/runner/Runner.rc` |
| Linux | `$XDG_DATA_HOME/dev.poli0981.marklens/marklens/` | `APPLICATION_ID` in `linux/CMakeLists.txt` |

**Both are load-bearing strings that look cosmetic**, and the Windows pair
especially so. `path_provider_windows` reads the executable's VERSIONINFO
resource and joins `CompanyName` with `ProductName`; editing either — for how
Explorer labels the program, say — silently relocates every user's session and
settings, and the old files are not migrated because nothing knows they were
ever there.

That happened once, on purpose, at M4. Correcting `ProductName` from `marklens`
to `MarkLens` and `CompanyName` from `dev.poli0981` to `poli0981` moved the
directory from `%APPDATA%\dev.poli0981\marklens\marklens\`. **Nothing was
stranded, because there was no release** — the repo had zero tags — and that is
precisely why the change belonged before v1.0.0 rather than after it. After a
release the same edit is a data-loss bug wearing a typographical disguise.

`test/repo/product_strings_test.dart` pins both strings and says why, so the
next person to improve how the program is labelled finds out what else they are
changing.

## Write discipline

- Atomic: write `<name>.json.tmp` → fsync → rename over the original. Both
  files go through one implementation, `core/storage/json_store.dart`, which
  is why that directory appears in the write allowlist of
  `test/architecture/no_write_test.dart` — it is the implementation of the
  config-directory write, not an exception to it, and a test asserts it
  touches nothing outside the `Directory` it was handed.
- Session writes debounce 1,000 ms (triggers in doc 03); **settings writes
  coalesce over 250 ms**. This paragraph used to say settings need no debounce
  because they change when a person clicks something. That is true of a
  checkbox and false of zoom: holding `Ctrl+=` is a stream of changes, and each
  one would be its own fsync-and-rename. A quarter of a second is below notice
  and turns a held key into one write (rule 7). The debounce lives in
  `app/settings_link.dart`, not in `SettingsStore`, which stays a plain atomic
  writer. **Quitting flushes both explicitly**, through the exit sequence in
  doc 03 ("App exit"). This paragraph used to say that disposing the stores
  flushed them, "so quitting never loses the last second" — and disposal does
  flush, but the `ProviderScope` is never disposed on a real exit: the process
  ends with the window. The hooks cover an in-process teardown (a test's
  container), not quitting. Until v1.0.1 nothing flushed settings on exit, and
  a change inside its 250 ms window — the last zoom step before Alt+F4 — was
  lost.
- Corruption on load: rename the bad file to `<name>.json.corrupt-<epoch>`,
  start from defaults/empty, show a one-time snackbar. Never crash, never
  silently delete the evidence.
- **Reading is total.** Every field that is missing, of the wrong type or out
  of range falls back to its default rather than failing the load, and a
  session entry that cannot be understood is dropped while the rest restore:
  losing one tab beats losing the session (rule 9). Two cases are discarded
  rather than repaired — a window geometry that is partial or smaller than
  200×200, because opening at the default beats opening one pixel tall or on
  a monitor that is no longer attached; and an `activePath` naming a document
  that is not in the open set, which would point the reader at nothing.

## session.json (schema v1)

```json
{
  "version": 1,
  "window": { "x": 120, "y": 80, "w": 1280, "h": 800, "maximized": false },
  "sidebarWidth": 280,
  "outlineVisible": true,
  "openRoots": ["D:/dev/omnideck/docs"],
  "files": [
    { "path": "D:/dev/omnideck/docs/README.md", "scroll": 0.42, "pinned": true }
  ],
  "activePath": "D:/dev/omnideck/docs/README.md",
  "recent": ["D:/notes/todo.md"],
  "lastUpdateCheck": "2026-08-28T09:30:00.000Z"
}
```

Notes:

- `files[]` is the flat open set (ad-hoc files *and* files opened from
  roots); `openRoots` additionally drives sidebar tree mode and watching.
- `scroll` is a 0..1 ratio — resilient to zoom and minor edits; the
  nearest-heading anchor in doc 03 refines it after external changes.
- Paths are stored absolute, canonicalized; display uses the platform's
  native separators.
- `recent` caps at `settings.recentLimit`, most recent first, deduped, and is
  **history rather than a view of the open set**. It was the latter until M3,
  which made "recent" mean "open": closing a file erased it from the list. It
  is also deduped case-insensitively, because that is how `OpenedFile.identity`
  judges sameness on Windows (doc 07) and a list holding `README.md` beside
  `readme.md` is showing one file twice.
- Missing files stay in `files[]` (badged at runtime); they are pruned only
  when the user closes them.
- `lastUpdateCheck` is what makes doc 11's "at most once per 24 h" survive a
  restart rather than meaning "once per launch". Added at M3 **inside schema
  v1**, deliberately: the field is advisory, an older build that drops it costs
  one extra HTTPS request, and a migration fixture for that would be ceremony.
  A schema bump is for a field whose loss costs something.

## settings.json (schema v1)

```json
{
  "version": 1,
  "language": "system",
  "theme": "system",
  "restoreSession": true,
  "recentLimit": 20,
  "reading": {
    "fontScale": 1.0,
    "contentMaxWidth": 760,
    "frontMatter": "collapsed"
  },
  "files": {
    "extensions": ["md", "mdx", "markdown", "mdown", "mkd", "mkdn", "mdwn"],
    "fileCap": 1000,
    "watchEnabled": true
  },
  "network": {
    "allowRemoteImages": false,
    "updateCheck": true
  }
}
```

Enums: `language` = system|en|vi|ja · `theme` = system|light|dark ·
`frontMatter` = collapsed|expanded|hidden. Ranges enforced on load:
`fontScale` 0.5–3.0, `contentMaxWidth` 560–1200 (or 0 = full width),
`fileCap` 100–2000, `recentLimit` 0–200, `sidebarWidth` 120–800.

The last two are additions, not part of the original schema. `recentLimit`
needed a bound because the recent list lives in `session.json` and an
unbounded limit lets that file grow without end; `sidebarWidth` needed one
because a restored session should never open a sidebar too narrow to read or
wide enough to hide the document. An empty `files.extensions` list also falls
back to the default set rather than being honoured — it would open nothing at
all, which is never what anyone meant.

### What building the Settings screen settled — M3

- **`restoreSession: false` freezes `session.json` rather than emptying it.**
  Not restoring is not the same as forgetting: if the session kept being
  written while the setting was off, the first launch with it off would
  overwrite the session it was told not to restore, and turning it back on
  would give an empty window forever. A switch you cannot un-flip is not a
  switch. The cost is that window geometry stops persisting too, which is
  consistent — the whole file is one feature, "where you were".
- **Every change is applied and written as it is made**, so the screen has a
  Close button and no OK/Cancel pair. A Cancel would need a second copy of the
  state to restore, and the 250 ms coalescing already means a slider drag is
  one write.
- **The widget ranges are the model's constants**, not new literals, so the
  screen cannot offer a value the loader would silently clamp. `contentMaxWidth`
  is the awkward one: `0` means *full width*, not "narrower than the minimum",
  so the slider reaches it by stepping one below `minContentWidth` — the only
  place a "no limit" end can live on a continuous control.
- **Three settings had no reader at all** until this landed, and had round-
  tripped through disk since M1 with nobody looking: `language` (the app set
  `supportedLocales` and never a `locale`), `restoreSession`, and
  `files.extensions` / `files.fileCap` (the file service was built with its
  defaults). `fileServiceProvider` is now derived from the settings, watching
  only `files` so a zoom step does not rebuild it.

  Note what `files.extensions` does *not* gate: `FileService.describe`. The
  registry decides what a **scan**, the dialog filter and drag-drop consider a
  document; a path named on the command line opens regardless, because doc 07
  says user intent wins.

### Reaching the running app

Settings are loaded once into `settingsProvider` (`app/settings_link.dart`) and
written back through it. Before M2 there was no such provider: the store was
exposed but `save` had no caller anywhere, so `settings.json` was read-only at
runtime and every preference here was unreachable. The one setting anything did
read — `recentLimit` — was fetched by loading the whole file off disk
synchronously on *every* session save.

Two of these lived twice over. `theme` sat beside a `ChromeState.themeMode`
that was never written to disk, and `reading.fontScale` beside a
`ChromeState.zoom` that was never read from it. The duplicates are gone rather
than synchronised: **settings own zoom and theme; the session owns panel
geometry**, which is what this document always said. The View menu's "Zoom" is
`reading.fontScale` under a shorter name.

**None of these settings changes parse output**, which is why the parsed-doc
cache key's `settingsRevision` component (doc 02) stays at zero in v1:
`reading.frontMatter` selects how the panel displays a block the splitter
lifts out either way, `network.allowRemoteImages` is resolved when an image
loads, and `files.extensions` decides what opens rather than how it parses.
The component is kept so that a future setting which *does* change a
`DocModel` cannot be added without meeting this paragraph.

## Migration policy

- Integer `version`, forward-only migration functions
  (`v1 → v2 → …`) applied in sequence on load; unknown *future* version →
  back up as `.bak-<epoch>` and start from defaults (downgrade safety).
- Unknown keys within a known version are dropped on next write; anything
  worth keeping gets a schema bump. Every migration ships with a fixture
  test (old file in, expected state out).

## Deliberate non-features

No cloud/sync of these files, no import/export UI in v1 (the files are
plain JSON — power users can copy them), no per-folder overrides.
