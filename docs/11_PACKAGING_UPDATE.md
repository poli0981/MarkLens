# 11 · Packaging & update

## Release artifacts (per tag)

| Artifact | Notes |
|---|---|
| `MarkLens-Setup-x.y.z.exe` | Inno Setup, x64, **per-user install** (no admin), registers file associations |
| `MarkLens-x.y.z-win-x64-portable.zip` | Unzip-and-run; no associations, config still in the standard app-support dir |
| `MarkLens-x.y.z-x86_64.AppImage` | Primary Linux artifact |
| `marklens_x.y.z_amd64.deb` | Ubuntu/apt-friendly; registers `.desktop` + MIME |
| `SHA256SUMS` | Checksums over all of the above |

MSIX and a Flathub submission are post-1.0 candidates, not v1 work.

## Windows (Inno Setup)

- Per-user (`PrivilegesRequired=lowest`), install under `%LocalAppData%`.
- File association: ProgId `MarkLens.Document` for `.md` and `.mdx` as an
  *optional task* (checked by default for `.md`, unchecked for `.mdx` —
  don't steal MDX from editors uninvited). "Open with" registration always.
- Single-instance forwarding (doc 02) makes double-click-while-running
  land in the existing window.
- Uninstall leaves the config dir; the uninstaller offers an optional
  "remove settings and session" checkbox.

## Linux

- **AppImage** built on the oldest supported base (Ubuntu 22.04 runner) for
  glibc compatibility. Known limitation, documented in the README: desktop
  integration/file association for AppImages requires the user's
  integration tooling; the `.deb` is the integrated path.
- **.deb**: installs `/usr/bin/marklens`, `marklens.desktop`
  (`MimeType=text/markdown;`), icon set, and runs
  `update-desktop-database` in postinst. Depends on GTK 3 per Flutter Linux
  requirements.
- CLI symmetry: `marklens README.md docs/` works identically on both OSes.

## Build hosts

Dev machine is Windows 11 — fine for Windows artifacts and day-to-day work.
**Linux release artifacts are built only in CI (ubuntu runner)**; WSL2/WSLg
is acceptable for local Linux smoke tests, never for shipping. Doc 14 wires
this.

## Versioning

SemVer `x.y.z`, git tag `vx.y.z`, single source of truth in `pubspec.yaml`
(`version: x.y.z+build`), surfaced via `package_info_plus` in About and the
update check.

## Update check (no auto-update)

- `UpdateService` (doc 03): at most once per 24 h, setting-controlled,
  HTTPS `GET api.github.com/repos/poli0981/MarkLens/releases/latest`.
- Strip `v`, compare SemVer against self; newer → passive banner
  "MarkLens x.y.z is available" → click opens the release page in the
  browser. No downloading, no self-replacement — packaging stays simple and
  the trust story stays clean.
- Failures (offline, rate-limited) are silent; logged to the ring buffer.

### What building it settled — M3

- **The interval needs somewhere to live**, or "at most once per 24 h" means
  "once per launch" and twenty launches in a day are twenty requests.
  `session.json` gains `lastUpdateCheck` — state, not a setting, so it belongs
  there rather than in `settings.json`. Added *inside* schema v1 rather than
  bumping it: the field is advisory, an older build that drops it costs exactly
  one extra request, and a migration fixture for that would be ceremony
  (doc 05).
- **The stamp is written whatever the answer was**, failures included. The
  interval exists to bound *requests*, and retrying on every launch because the
  last one was offline is the behaviour it is there to prevent.
- **Help → Check for Updates ignores the interval but not the setting.**
  Turning checks off is a statement about network traffic, and a menu item that
  overrode it would make the setting advice. It also always answers — "up to
  date" included — because the automatic check is silent by design and a button
  that says nothing looks broken. That one bit, "was this asked for", is the
  only difference between the two paths.
- **The request carries nothing but itself.** No version, no identifier, no
  header of ours beyond the `Accept` and `User-Agent` GitHub needs to answer
  properly. The only thing the server learns is that somebody asked.
- **A draft or a prerelease is not an upgrade**, and neither is `1.0.0-rc.1`
  for someone running `1.0.0` — SemVer §11, and the one comparison that would
  be embarrassing to get backwards.

## House-convention note

Velopack is the usual update pipeline in this portfolio; it has no
first-class Flutter path, so MarkLens deviates deliberately: installer +
tag-check banner instead. Recorded here so future-us doesn't "fix" it
accidentally. Revisit only if a mature Flutter binding appears.
