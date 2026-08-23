# 05 · Session & settings

## Location

`getApplicationSupportDirectory()/marklens/` →
`session.json`, `settings.json`. These two files are the app's entire disk
footprint besides its installation (rule 1).

## Write discipline

- Atomic: write `<name>.json.tmp` → fsync → rename over the original.
- Session writes debounce 1,000 ms (triggers in doc 03); settings write on
  change.
- Corruption on load: rename the bad file to `<name>.corrupt-<epoch>`, start
  from defaults/empty, show a one-time snackbar. Never crash, never silently
  delete the evidence.

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
  "recent": ["D:/notes/todo.md"]
}
```

Notes:

- `files[]` is the flat open set (ad-hoc files *and* files opened from
  roots); `openRoots` additionally drives sidebar tree mode and watching.
- `scroll` is a 0..1 ratio — resilient to zoom and minor edits; the
  nearest-heading anchor in doc 03 refines it after external changes.
- Paths are stored absolute, canonicalized; display uses the platform's
  native separators.
- `recent` caps at `settings.recentLimit`, most recent first, deduped.
- Missing files stay in `files[]` (badged at runtime); they are pruned only
  when the user closes them.

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
`fileCap` 100–2000.

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
