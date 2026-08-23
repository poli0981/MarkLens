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
  HTTPS `GET api.github.com/repos/poli0981/marklens/releases/latest`.
- Strip `v`, compare SemVer against self; newer → passive banner
  "MarkLens x.y.z is available" → click opens the release page in the
  browser. No downloading, no self-replacement — packaging stays simple and
  the trust story stays clean.
- Failures (offline, rate-limited) are silent; logged to the ring buffer.

## House-convention note

Velopack is the usual update pipeline in this portfolio; it has no
first-class Flutter path, so MarkLens deviates deliberately: installer +
tag-check banner instead. Recorded here so future-us doesn't "fix" it
accidentally. Revisit only if a mature Flutter binding appears.
