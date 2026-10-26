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

`.github/workflows/ci.yml`. Five jobs:

`analyze` → `test` → `golden` and `sonarcloud`, with `build-smoke` branching
off `analyze`.

- **`analyze`** (ubuntu): `flutter analyze`, `dart format --set-exit-if-changed`,
  a `gen-l10n` no-diff check (generated ARB output is committed, so
  regenerating must produce no diff), and an assertion that no golden failure
  dump is tracked (doc 12).
- **`test`** (matrix `ubuntu-latest` + `windows-latest`): unit, widget and
  architecture tests with `--exclude-tags "golden || watcher-live"`. The ubuntu
  leg then checks doc 12's coverage thresholds against its own lcov report —
  `lib/core/` at least 85% of lines, `lib/` at least 70%, generated l10n left
  out — and uploads the report as an artifact for `sonarcloud`.
- **`golden`** (`ubuntu-24.04`, pinned): activates itself by grepping for the
  literal `@Tags(['golden'])`, so a golden costs nothing until one exists.
- **`sonarcloud`** (after `test`): SonarQube Cloud analysis of `lib/` with that
  coverage report. A failed quality gate fails the job. See below.
- **`build-smoke`** (matrix): a debug build boots on both platforms.

**The Flutter version is `env.FLUTTER_VERSION`, and it is duplicated** — into
`release.yml`, `watch-observation.yml`, both `tool/*/Dockerfile`s, the README's
stack line, the notices table, and doc 01, which is the source of truth. Doc 01
says they "must never disagree"; since M4 that is a test rather than a rule, in
`test/repo/pin_agreement_test.dart`, which since 2026-10 also holds every
shipped package pin to doc 01's table and the notices.

**Caching belongs to `subosito/flutter-action` and should stay there.** Setting
`cache: true` and leaving `pub-cache` unset enables *both* caches, and the
action keys the pub one on `hashFiles('**/pubspec.lock')` itself. So "caches
keyed on the lockfile" is already true, and adding an `actions/cache` step to
make it true would give the same path two owners. Read the action before
changing this; the absence of a visible cache step in `ci.yml` is not the
absence of a cache.

**The coverage thresholds switched on in 2026-10**, after saying "at M1" from
M0 to v1.0.1 and gating nothing. They were measured before they were enforced,
so turning them on could not turn `main` red by surprise: 96.6% of `lib/core/`
and 92.2% of `lib/` on the day. The check is a dozen lines of `awk` over the
lcov report rather than an action or a script in `tool/`, because the report
format is that simple and doc 13 prefers our own fifty lines.

## SonarQube Cloud

Project `poli0981_MarkLens` in organization `poli0981`; configuration in
`sonar-project.properties` at the repo root, which says why each line is there.

**CI-based, not automatic analysis.** Automatic analysis is switched off on the
SonarQube Cloud side and must stay off — two analyses of one project conflict.
It cannot run `flutter pub get`, so the Dart analyzer would resolve none of the
`package:` imports, and it never sees coverage. The `sonarcloud` job runs after
`test`, sets up the same Flutter pin, runs `pub get`, downloads the ubuntu
leg's lcov report and scans. `sonarqube-scan-action` is v6 or later on purpose:
up to v3 it ran in a container that could see only the checkout, which is
exactly the pub-cache blindness above.

**What is analysed:** `lib/` as source, `test/`, `integration_test/` and
`test_driver/` as tests, `lib/l10n/gen/` excluded (generated, and committed only
so a fresh clone analyzes clean). The C++ runners and the Python tools are
CodeQL's (below): C++ in SonarQube Cloud needs a compilation database the
Flutter build does not produce.

**The quality gate fails the job** (`sonar.qualitygate.wait`), so a red gate is
a red check on the pull request rather than a badge somebody has to remember to
look at. `sonar.projectVersion` comes from `pubspec.yaml` in the job, because
the "previous version" new-code period keys on it: every release starts a new
period, and the gate judges what changed since.

**The free plan reads back `main` and pull requests into `main`, and nothing
else.** A pull request is analysed as a pull request — issues on the lines it
changed, nothing more — so the full issue list lives on `main`'s analysis. A
*branch* analysis is a paid feature: it uploads, and then the quality-gate
query answers 403 ("not allowed to access data from non main branches"). The
first run of the job found that by dispatching `ci` on a feature branch, which
is why `ci` has no `workflow_dispatch` trigger: on this plan there is nothing
for it to do that a re-run of the last `main` run does not.

**`SONAR_TOKEN` is the one repository secret**, and it is read by this job
alone. A pull request from a fork and anything Dependabot opens run without
repository secrets, so the job skips itself there rather than failing on
authentication; everywhere else a missing token fails loudly. It is long-lived,
and it is allowed because it reaches SonarQube Cloud and nothing here — see
"Non-negotiables" for why that is the line, and why a WinGet token is on the
other side of it.

## Code scanning, dependency audit, Dependabot

- **CodeQL** (`codeql.yml`; push to `main`, every PR, weekly): `actions`,
  `c-cpp` and `python`, all with `build-mode: none`. CodeQL has no Dart. What it
  covers is everything else that runs: the workflows (the only place here that
  holds a writable token), the C++ runners, and the Python under `tool/`.
  Build-free C++ extraction has been GA since 2025-10, so the job needs no
  Flutter toolchain, Windows SDK or GTK. The job holds `security-events: write`
  to upload results, the second write grant in the repository and the only
  other one `workflow_lint_test.dart` allows.
- **Dependency review** (`dependency-review.yml`, every PR): what the PR does
  to the dependency graph — `pubspec.lock` and the actions pinned here —
  against the advisory database, so a version with a known advisory fails at
  review time rather than arriving as an alert after the merge.
  **Vulnerabilities only**, and the reason is worth keeping: it was written
  with a GPL-compatible licence allow-list, and its first run failed every pub
  package. GitHub's dependency graph reports pub licences in lowercase (`mit`,
  `bsd-3-clause`), the action's SPDX parser rejects those as invalid, and an
  unparseable licence is a hard failure there. Rule 10's licence check
  therefore stays wholly a person's (doc 01); the workflow says when to switch
  the allow-list back on.
- **Dependabot** (`dependabot.yml`): `github-actions` and `pub`, each grouped
  into one pull request a month. The `pub` group is doc 01's monthly batch PR,
  opened by a bot; the licence check and the doc 01 / notices rows stay a
  person's, and `test/repo/pin_agreement_test.dart` keeps the batch red until
  they are done. Dependabot alerts and security updates are on in the
  repository settings, as are secret scanning and push protection.

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
job with a timeout, no `-latest` image anywhere in `release.yml`, **exactly
one** job in the repository declaring `contents: write`, and no other write
grant anywhere but CodeQL's `security-events: write`.

**WinGet is deliberately not a job here.** A pull request on
`microsoft/winget-pkgs` has to come from a fork, which takes a classic token on
the maintainer's account — long-lived, and able to write to every public
repository that account owns, this one's releases included. The
non-negotiables below exist to keep exactly that out of the pipeline, so WinGet
is a step on the release checklist (doc 15), run from the maintainer's machine
by `tool/winget/submit.ps1` after a person has published the draft; doc 11 has
the procedure.

## Non-negotiables

Least-privilege permissions everywhere, no long-lived secret that can write to
this repository or anything it publishes (release uses the ephemeral
`GITHUB_TOKEN`), SHA-pinned third-party actions **and tools**, and Linux
artifacts never built outside CI.

The secret rule was "no long-lived secrets" until 2026-10, when `SONAR_TOKEN`
became the first stored secret. The wording moved to what the rule was always
for — the WinGet section above is the same argument — and the token fits it:
whatever it can do, it does on SonarQube Cloud. It cannot push here, publish a
release, or reach any repository. (It is a user token, so on SonarQube Cloud it
carries its owner's permissions; that is the maintainer's to scope there.)

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
