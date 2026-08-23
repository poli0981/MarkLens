# CLAUDE.md — MarkLens build rules

MarkLens is a read-only Markdown viewer (Flutter/Dart, Windows + Ubuntu,
GPL-3.0-only). You are helping a solo maintainer. The `docs/` suite is the
specification; this file is the law layer on top of it.

## The ten hard rules

1. **Read-only invariant.** Never write, rename, move, or delete a user
   document, under any code path. The app's only writes go to its own config
   directory (session, settings, exported logs). No "convenience" exceptions.
2. **Render, not run.** Never execute MDX, JSX, embedded HTML, or any script
   from document content. Never add a webview or JS-engine dependency. MDX is
   displayed as inert placeholders per `docs/04_MARKDOWN_PIPELINE.md`.
3. **`lib/core/` is pure Dart.** No `package:flutter` import anywhere under
   `core/`. The architecture test in `test/architecture/` enforces this; do
   not weaken that test.
4. **Every user-facing string goes through ARB l10n** (en/vi/ja). No hardcoded
   UI strings, no string concatenation for sentences. See `docs/09_I18N.md`.
5. **Zero network by default.** The only permitted network calls are the
   GitHub Releases update check and remote-image loading — both
   setting-controlled, the latter off by default. No telemetry, no analytics,
   no "phone home", ever.
6. **All rendering flows through the `MarkdownRenderer` interface** in
   `features/reader/rendering/`. Renderer packages are imported nowhere else,
   so the S1 spike decision stays swappable. The parse half of the pipeline
   lives in `core/markdown/` and stays pure Dart per rule 3 — it ends at a
   `DocModel`, never at widgets. Rule 3 wins any conflict with this rule.
7. **Persistence writes are debounced and atomic** (write temp → rename).
   Never write on every scroll tick or keystroke.
8. **Parse lazily.** Only the active document is parsed on activation; the
   parsed-document cache (`DocModel`, pure Dart) is LRU (default 40). Never
   eagerly parse the whole open set, and never cache widgets.
9. **Untrusted input never crashes the app.** Any parse/render failure
   degrades to a plain-text view with a notice bar. Fuzz-minded: assume every
   input file is adversarial.
10. **New dependency ⇒ same-PR updates** to `docs/01_TECH_STACK.md` and
    `legal/THIRD_PARTY_NOTICES.md`, with license verified.

## Working agreements

- Docs are law: if code needs to deviate, update the doc in the same PR and
  say why in the PR description. Never silently drift.
- Before implementing a feature, read its doc section; before touching
  rendering, read doc 04; before touching persistence, read doc 05.
- Conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`,
  `refactor:` with optional scope). Small, reviewable PRs.
- Placeholders `{{CONTACT_EMAIL}}`, `{{RELEASE_DATE}}` are filled by the
  maintainer — leave them intact.
- Definition of Done per feature: `docs/12_TESTING.md` §DoD.

## Commands

```bash
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test                      # unit + widget
flutter test test/architecture    # boundary enforcement only
flutter build windows / linux
```

## Repo map (target)

```
lib/
  main.dart          # args, single-instance, bootstrap
  app/               # shell, menu bar, shortcuts, providers wiring, theme
  core/              # PURE DART: models, files, markdown, session, watch,
                     # settings, update, search
  features/          # sidebar, tabs, reader, outline, search, settings_ui, about
  l10n/              # app_en.arb, app_vi.arb, app_ja.arb
test/
  core/  features/  architecture/  fixtures/torture/
```

Module boundaries and the full tree: `docs/02_ARCHITECTURE.md`.
