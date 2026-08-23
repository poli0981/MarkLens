# 14 · CI / CD

## House pattern

Thin **caller stubs** in this repo delegate to reusable workflows in
`poli0981/.github`, with an explicit `permissions:` block on every caller
and actions pinned by SHA per ops-repo convention.

**Gap:** the ops suite (13 reusable workflows, 9 language stacks) does not
yet cover Dart/Flutter. → **Action A-1: contribute a
`reusable-flutter-ci.yml` (and `reusable-flutter-release.yml`) to
`poli0981/.github`**, following the suite's existing input/secret shape and
naming. Until A-1 lands, MarkLens carries the same jobs as inline workflows
written lift-and-shift-ready (job names and inputs already matching the
future reusable).

## CI (every PR + main)

```yaml
# .github/workflows/ci.yml (caller stub, target shape)
name: ci
on: [push, pull_request]
permissions:
  contents: read
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  flutter-ci:
    uses: poli0981/.github/.github/workflows/reusable-flutter-ci.yml@<pin>
    with:
      flutter-version: "3.47.1"   # exact pin recorded in doc 01
```

Reusable-side jobs: `analyze` (analyze + format check + a `gen-l10n`
no-diff check) → `test` (unit/widget + architecture tests, coverage artifact,
thresholds from doc 12; windows runs `--exclude-tags golden`) → `golden`
(ubuntu only) → `build-smoke`
(matrix: `windows-latest`, `ubuntu-latest`; debug build boots). Timeouts on
every job; Flutter/pub caches keyed on the lockfile.

## Release (tag `v*`)

`release.yml` caller → reusable release workflow; `permissions:
contents: write` scoped to the publish job only.

1. `windows-latest`: `flutter build windows --release` → Inno (`iscc`) →
   installer + portable zip.
2. `ubuntu-22.04` (deliberately the floor image, doc 11):
   `flutter build linux --release` → `appimagetool` → AppImage; `dpkg-deb`
   → `.deb`.
3. Aggregate job: `SHA256SUMS`, draft GitHub Release with all artifacts and
   generated notes; publishing the draft stays a manual click after the
   clean-VM smoke test (doc 15 checklist).

## Non-negotiables

Least-privilege permissions everywhere, no long-lived secrets (release uses
the ephemeral `GITHUB_TOKEN`), SHA-pinned third-party actions, goldens only
on ubuntu, Linux artifacts never built outside CI.
