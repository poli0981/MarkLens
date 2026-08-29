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

`.github/workflows/release.yml`. Four jobs, `permissions: contents: read` at
the top and `contents: write` on the publish job alone.

1. **`verify-version`** — `pubspec.yaml`, `lib/app/version.dart` and the tag
   must agree. First, and cheap, because it guards the most expensive mistake
   in the pipeline: `UpdateService` parses `tag_name` and nothing else, so a tag
   that does not SemVer-parse after stripping `v` makes the update check a
   silent no-op for every user, and the code path simply returns `null` rather
   than failing anywhere visible.
2. **`windows` (`windows-2025`)** — `packaging/windows/build.ps1`: a release
   build, `iscc`, and the portable zip. The script *warns* rather than failing
   when `iscc` is absent, which is right on a dev machine and wrong here, so the
   job asserts both files exist and are not suspiciously small.
3. **`linux` (`ubuntu-24.04`, building inside `ubuntu:22.04`)** — one release
   build, packaged twice by `build-deb.sh` and `build-appimage.sh`, then both
   artefacts are *started* under `xvfb` rather than merely weighed. See doc 11
   for why the floor is a container image rather than a runner label.
4. **`publish`** — the four artefact names are checked against doc 11's table,
   `SHA256SUMS` is written with names and no paths so `sha256sum -c` works
   wherever somebody downloaded them, and `gh release create --draft` opens a
   draft.

**`gh` rather than a fourth third-party action.** It is preinstalled and
`GITHUB_TOKEN`-authenticated, and it removes one SHA to maintain from the blast
radius of the only job in the repository that can write to it (doc 13 prefers
fifty lines of our own over a dependency).

**`workflow_dispatch` builds everything and publishes nothing.** The repo had no
tags when this was written, so the first run of a release workflow must not be
the real one; a dispatch run reaches every build job, uploads all four
artefacts, and never enters `publish`.

**The draft is not a formality.** `UpdateService` ignores drafts *and*
prereleases, so nothing reaches a user until a person publishes — after the
clean-VM smoke and the read-only audit (doc 15). The corollary is the one to
remember on release day: ticking "prerelease" on v1.0.0 does not delay the
update banner, it disables it permanently.

`test/repo/workflow_lint_test.dart` holds the shape: every action pinned to a
40-character SHA, every workflow with an explicit `permissions:` block, every
job with a timeout, no `-latest` image anywhere in `release.yml`, and **exactly
one** job in the repository declaring `contents: write`.

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
