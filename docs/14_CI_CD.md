# 14 · CI / CD

## House pattern, and where MarkLens leaves it

The convention elsewhere in this portfolio is a thin **caller stub** delegating
to a reusable workflow in `poli0981/.github`, with an explicit `permissions:`
block on every caller and actions pinned by SHA. That ops suite exists and is
public; it carries twelve `reusable-*.yml` across nine language stacks, and
**none of them is Dart or Flutter**.

**Action A-1 — contributing `reusable-flutter-ci.yml` and
`reusable-flutter-release.yml` to `poli0981/.github` — is dropped from v1**
(doc 15, "M4 build order", decision 5). Through M0–M3 this document described
the inline jobs as a placeholder "written lift-and-shift-ready", which was a
reasonable thing to plan and a poor thing to keep believing: designing the
input and secret interface of a reusable *release* workflow before this repo
has ever cut a release means abstracting something nobody here has done. The
inline workflows are therefore the real ones, not a stand-in for them, and this
document describes what is in `.github/workflows/` rather than what might
replace it. A-1 becomes worth doing when a second Flutter project appears, at
which point there will be one working pipeline to generalise from instead of
zero.

What survives from the convention, because it is what the convention was for:
an explicit least-privilege `permissions:` block on every workflow, every
third-party action pinned by 40-character SHA, and a timeout on every job.

## CI (every PR + main)

`.github/workflows/ci.yml`. Four jobs:

`analyze` → `test` → `golden`, with `build-smoke` branching off `analyze`.

- **`analyze`** (ubuntu): `flutter analyze`, `dart format --set-exit-if-changed`,
  a `gen-l10n` no-diff check (generated ARB output is committed, so
  regenerating must produce no diff), and an assertion that no golden failure
  dump is tracked (doc 12).
- **`test`** (matrix `ubuntu-latest` + `windows-latest`): unit, widget and
  architecture tests with `--exclude-tags "golden || watcher-live"`, coverage
  uploaded as an artifact from the ubuntu leg. The doc 12 coverage thresholds
  are **not** enforced here yet — see the note below rather than assuming they
  are.
- **`golden`** (`ubuntu-24.04`, pinned): activates itself by grepping for the
  literal `@Tags(['golden'])`, so a golden costs nothing until one exists.
- **`build-smoke`** (matrix): a debug build boots on both platforms.

**The Flutter version is `env.FLUTTER_VERSION`, and it is duplicated** — into
`watch-observation.yml`, into `tool/goldens/Dockerfile`, and into doc 01, which
is the source of truth. Doc 01 says the four "must never disagree"; since M4
that is a test rather than a rule, in `test/repo/pin_agreement_test.dart`.

**Caching belongs to `subosito/flutter-action` and should stay there.** Setting
`cache: true` and leaving `pub-cache` unset enables *both* caches, and the
action keys the pub one on `hashFiles('**/pubspec.lock')` itself. So "caches
keyed on the lockfile" is already true, and adding an `actions/cache` step to
make it true would give the same path two owners. Read the action before
changing this; the absence of a visible cache step in `ci.yml` is not the
absence of a cache.

**Known gap, stated rather than implied:** doc 12 says the coverage thresholds
(core ≥ 85%, overall ≥ 70%) switch on at M1. They did not. `coverage/lcov.info`
is uploaded every run and gated by nothing. M4 prints the real numbers before
deciding whether to enforce them or amend doc 12 — turning `main` red on an
unmeasured threshold during a release week is not a gate, it is an accident.

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
the ephemeral `GITHUB_TOKEN`), SHA-pinned third-party actions **and tools**, and
Linux artifacts never built outside CI.

"And tools" was added at M4, because the release path downloads two binaries
that no `uses:` pin covers: `appimagetool`, and the AppImage runtime that
appimagetool fetches on its own and embeds in the artefact. Both are pinned by
tag and verified by SHA-256 before execution (doc 11). The rule is the same one
the actions pin expresses — nothing that runs in the workflow holding
`contents: write` may be whatever the internet served that morning.

**Goldens run only on the *pinned* ubuntu image**, not merely "on ubuntu". A
golden is a byte comparison, so the image that checks one has to be the image
that made it, and `-latest` labels move: `ubuntu-latest` is 24.04 today with
26.04 images already published. The day it moves, every golden fails at once
with nothing wrong in any layout — a failure that reads like a flake and is
not. The job pins `ubuntu-24.04`, `tool/goldens/Dockerfile` builds `FROM
ubuntu:24.04`, and a test asserts the two agree.
