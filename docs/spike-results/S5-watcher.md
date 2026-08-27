# S5 — Watcher save-pattern matrix

**Status:** complete on both platforms' *filesystem* behaviour; the
editor-identity half needs one confirming save from the maintainer
**Branch:** `spike/s5-watcher`
**Machines:** Windows 11 / NTFS (this machine) · Ubuntu / ext4 (CI runner)
**Date:** 2026-08-23

Doc 15 asks for saves from VS Code, Notepad++ and vim on Windows, and VS Code
and vim on Ubuntu, checked against the WatchService normalizer. Pass: every
save lands as a single `changed` within 500 ms, and no false `missing` badge
during an atomic save.

## How this was measured

The editors are not installed here, so rather than guess at their event
sequences the spike reproduces the **filesystem operations** each one performs
and records what the real `watcher` package reports, on a real directory, on
each platform. Ubuntu came from a one-off CI job, since S3's VM is deferred.

That leaves exactly one thing unmeasured: *which* editor uses *which* pattern.
That is a question one save answers — see "What is left" below.

## What the watcher actually reports

Windows 11 / NTFS (`RecursiveDirectoryWatcher`):

| Pattern | Events | Timing |
|---|---|---|
| P1 write in place | `modify` | 10 ms |
| P2 temp + rename over | `modify` | 14 ms |
| P3 delete + recreate | `remove`, `add` | 7, 28 ms |
| P4 rename away + rewrite | `remove`, `add`(backup), `add` | 8, 8, 29 ms |
| P5 five rapid writes | `modify` × 5 | 6 → 135 ms |
| P6 real deletion | `remove` | 7 ms |

Ubuntu / ext4 (`LinuxDirectoryWatcher`):

| Pattern | Events | Timing |
|---|---|---|
| P1 write in place | `modify` × **2** | 7, 8 ms |
| P2 temp + rename over | `add`(temp), `modify`, `remove`(temp) | 1, 4, 4 ms |
| P3 delete + recreate | `remove`, `add` | 1, 22 ms |
| P4 rename away + rewrite | `add`(backup), `remove`, `add` | 0, 0, 22 ms |
| P5 five rapid writes | `modify` × **10** | 1 → 131 ms |
| P6 real deletion | `remove` | 0 ms |

Three things doc 07 did not know:

- **An atomic temp+rename is not a delete/create pair.** Doc 07 predicted
  "delete+create or rename pairs"; both platforms report a plain `modify` on
  the destination. The prediction *is* right for P3 and P4, which is where the
  danger actually lives.
- **Linux doubles every write.** inotify reports content and metadata
  separately, so a single save is two `modify` events and five saves are ten.
  Debouncing is not an optimisation here, it is required for correctness.
- **Linux emits events for the editor's temp and backup files.** `note.md.tmp`
  and `note.md~` both surface. The extension registry filters them before the
  normalizer sees them, but only because it filters by extension — a temp file
  named `note.md` in a sibling directory would not be caught this way.

## The classification rule

P6 (`remove` at 7 ms, nothing after) and P3 (`remove` at 7 ms, `add` at 28 ms)
are **byte-identical at the moment the first event arrives**. No amount of
inspecting event types can tell a deletion from an atomic save; only waiting
can.

So: **when a path's debounce window closes, classify by whether the path
exists.** Never by the event kinds. That single rule handles every row above —
P1–P5 all end with the file present and become one `changed`; P6 ends with it
absent and becomes `missing`.

The widest gap inside a single save was 29 ms, against a 200 ms debounce
window (doc 07). An order of magnitude of headroom, and the only cost of that
window is how late a reload feels.

`lib/core/watch/watch_normalizer.dart` implements it in pure Dart — it never
touches the filesystem, asking a caller-supplied `pathExists` instead, which is
what lets `test/core/watch_normalizer_test.dart` replay these exact sequences
with these exact gaps.

## The finding that changes doc 07

Doc 07 says "**individual file watchers for ad-hoc files**". Measured latency
for one ad-hoc file, same file, same machine:

| Approach | Windows | Linux |
|---|--:|--:|
| `FileWatcher` | **1000 ms** (`PollingFileWatcher`) | 1 ms (`NativeFileWatcher`) |
| Watch the parent directory, filter by path | **7 ms** | ~1 ms |

`File.watch` does not work on Windows, so the package silently substitutes
polling on a one-second timer — **twice the 500 ms budget doc 15 sets**, and it
would have shipped as a mysteriously laggy reload for exactly the "keep a
README open beside the editor" case the charter is built around.

**Ad-hoc files are watched through their parent directory, never with
`FileWatcher`.** Doc 07 amended. The cost is receiving events for unrelated
files in that directory, which the path filter discards.

## What is left

Which editor performs which pattern. The patterns are all covered either way —
whatever VS Code does, it is one of P1–P5, and all five normalize to a single
`changed`. So this is a confirmation, not a risk.

To close it, open a document in MarkLens once the reader lands at M1, save it
from VS Code, Notepad++ and vim, and check the reload is single and prompt. If
any editor produces a sequence not in the table above, add it to
`test/platform/watch_observation_test.dart` and it becomes a regression test.

### Confirmed for Notepad++ — 2026-08-27

**Notepad++ on Windows 11/NTFS: the reload is single and immediate.** The
maintainer saved a document open in MarkLens and it updated at once, with no
`missing` badge flashing in between — which is the observable half of the
classification rule, since a false `missing` is exactly what a delete-then-write
save would produce if the kinds were being trusted.

That was the first save this could be checked against at all: the watcher only
came into existence at M2, so from M0 to M1 there was nothing running to
confirm it against.

Whatever pattern Notepad++ used, it normalized as the table predicts, and no
sequence outside P1–P6 surfaced. **VS Code and vim are still unconfirmed** —
the same low-risk confirmation, for the same reason: every pattern in the table
ends the same way.

Re-run the observations any time with:

```bash
flutter test --tags watcher-live test/platform/watch_observation_test.dart
```
