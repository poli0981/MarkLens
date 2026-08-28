# 13 · Code quality

## Static analysis

`very_good_analysis` as the base ruleset; project deltas live in
`analysis_options.yaml` with a comment justifying each. `flutter analyze`
and `dart format --set-exit-if-changed .` gate every PR (doc 14).

## Conventions

- Effective Dart naming throughout. **No `Ml*` class prefix** — deliberate
  deviation from the web-project convention: Dart disambiguates via import
  namespacing, and prefixing fights the ecosystem style. Feature folders +
  clear names (`SidebarTree`, `DocCache`) carry the organization instead.
- Files ≤ ~400 lines as a soft guideline; split by responsibility, not by
  ceremony.
- No `dynamic` in app code; `Object?` + pattern matching where genuinely
  needed.
- Public members of `core/` documented with `///` — core is the app's API.
- TODOs as `// TODO(kokone): …` and must reference an issue before merge to
  `main`.

## Git

- `main` protected; work on `feat/*`, `fix/*`, `docs/*` branches.
- Conventional commits (`feat(reader): …`, `fix(watch): …`); squash-merge
  with a clean title — **except where a milestone decides otherwise**. That
  rule is paired with the next one, "PRs small enough to review in one
  sitting", and `main`'s history is already one commit per feature; M2 and M3
  were both rebase-merged for that reason, recorded in doc 15's build-order
  sections. Decided per milestone rather than settled, so the two are not
  allowed to drift silently.
- PR checklist mirrors the DoD (doc 12); PRs stay small enough to review in
  one sitting.

## Dependencies

Rule 10 (CLAUDE.md): a new package needs a reason in the PR description,
a row in doc 01, a row in `legal/THIRD_PARTY_NOTICES.md`, and a license
check. Prefer the standard library and 50 lines of our own code over a
utility dependency.
