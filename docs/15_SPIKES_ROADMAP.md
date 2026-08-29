# 15 · P0 spikes & roadmap

Feature work does not start until the spikes that *gate design decisions*
pass. Each spike is a throwaway branch with a written result note committed to
`docs/spike-results/`.

**As of 2026-08-23: S1, S2, S4 and S5 have passed and M0 is closed.** S3 is
deliberately deferred — see below. Every decision they settled is recorded in
doc 01 (pins), doc 03 and doc 07 (watching), doc 04 (pipeline) and doc 06
(selection, menu bar).

**As of 2026-08-28, M0–M3 are closed and merged.** Every feature in the
charter's v1 scope exists. What is left is M4: artefacts, the two decisions
blocking them, and the tag — see "Start M4 here".

## S1 — Renderer bake-off *(the decision spike)*

> **COMPLETE — 2026-08-23.** `flutter_markdown_plus 1.0.12` as the renderer
> (ratified after S2), and `highlight 0.7.0` as the syntax highlighter — the
> pure-Dart engine, with the `flutter_highlight` widget wrapper dropped
> (`docs/spike-results/S1c-highlighter.md`). Both pinned in doc 01, with the
> accepted language-coverage gaps written down there.
>
> **Measurable criteria closed — 2026-08-23.** Fidelity sweep, the three
> structural questions, and the profile-mode scroll gate are all done; results
> in `docs/spike-results/S1-renderer-bakeoff.md`.
>
> **Both candidates pass the fps gate by roughly an order of magnitude** (zero
> missed frames; p99 frame build ~2.4 ms against an 18.18 ms budget), and first
> paint on a typical 100 KB document is 70 ms against the 150 ms budget. So
> performance does not discriminate between them, and the recommendation —
> candidate A, on maintenance grounds — rests on the non-performance findings.
>
> **Fully closed 2026-08-26.** The last open criterion was the doc 06
> styling-token check, which was blocked until M1 defined the tokens. It does
> now: `ReaderStyle` drives the renderer entirely from the eight tokens, so it
> picks no colour of its own, and the code-scope map is derived from the same
> set. The highlighter decision closed earlier, in S1c.

Render the torture corpus (doc 12) with `flutter_markdown_plus` and
`markdown_widget`.
**Pass:** GFM checklist fully correct (tables incl. wide-scroll, task
lists, fenced code, images, footnote behavior recorded either way); 1 MB
document scrolls ≥ 55 fps average on the dev machine; styling hooks
sufficient for the doc 06 theme tokens. **Output:** winner + exact pin
recorded in doc 01, wrapper notes for `MarkdownRenderer`.

Maintenance and licensing for both candidates were verified 2026-08-23 and are
recorded in doc 01 — `markdown_widget` has not shipped in ~16 months and drags
in four extra packages. Do not re-derive that; score fidelity and performance.

### S1 must also answer three structural questions

These surfaced from reading docs 04, 06 and 08 against each other. No document
answers them, and they decide whether the specified behaviour is buildable at
all — so they belong here, not in M2 when it is expensive to be wrong.

1. **Does the block index survive contact with the renderer?**
   `markdown`'s `Element` carries no source position (doc 04), so the pipeline
   builds its own top-level block index. S1 confirms that index actually lines
   up with the widgets the renderer produces — otherwise doc 08's
   "hit → block → scroll" and `#anchor` jumps have nothing to aim at.
2. **One widget for the whole document, or one widget per block?**
   Per-block gives block-laziness (doc 04), scroll-to-block (doc 08) and
   anchor jumps (doc 06) almost for free — but each block then parses in
   isolation, which breaks reference links (`[text][ref]`) and footnotes whose
   definitions live in another block. Measure both; record which cross-block
   constructs break and whether the renderer exposes a way to pre-seed link
   references.
3. **`SelectionArea` versus a lazy list.**
   Doc 06 wants the whole document inside one `SelectionArea` and S2 makes
   that a release gate; doc 04 wants lazy block building; doc 00 wants 55 fps
   on 1 MB. A lazily-built child that has not been built cannot be selected,
   so these three do not automatically hold together. If they cannot all be
   met, say which one gives, and amend the doc that loses.

### S1 also closes the highlighter decision — **done**

`highlight 0.7.0`, used directly. The premise for looking past the incumbent
was fresher grammars, and measurement killed it: `re_highlight` produced
*identical* scopes on Dart 3, including the class modifiers. The incumbent then
wins on the things that were measurable — an unknown language degrades to plain
text rather than throwing, ~1.5× faster tokenising, pure Dart with one
dependency. `syntax_highlight` cannot resolve against our pins at all.
Full reasoning and the accepted gaps: `docs/spike-results/S1c-highlighter.md`.

## S2 — Selection & copy quality

> **PASSED — 2026-08-23.** Results in `docs/spike-results/S2-selection.md`.
> Cross-block copy is clean, Vietnamese and Japanese survive, and code-block
> indentation is preserved, so the S1 choice stands.
>
> One requirement did not survive contact: whole-document `SelectionArea`
> needs every block built, which costs 527 ms to first paint at 100 KB and
> kills the app at 1 MB. **Laziness and 55 fps win**; doc 06 now specifies
> File → Copy entire document (`Ctrl+Shift+C`) instead, reading the `DocModel`
> rather than the widget tree. Drag selection with auto-scroll already covers
> ordinary passage selection — 50 contiguous paragraphs where 22 were built.

Wrap the S1 winner's output in `SelectionArea`; also test its native
`selectable` mode.
**Pass:** select across heading + paragraph + code block + table cell
yields clean clipboard text (newlines sane, no widget artifacts); VI
diacritics and JA text select correctly; code-block copy button preserves
formatting exactly. **Fail here = revisit S1 choice before anything else.**

## S3 — Ubuntu clean-VM run

> **DEFERRED by decision — 2026-08-23.** Not a gate on M1. A clean-VM run is
> most informative against an app that actually opens documents, and it is
> cheap to schedule once rather than repeatedly against a shell. It moves to
> the M4 release checklist, where it already appears.
>
> Two of the things S3 would have caught are already answered without a VM:
> `build-smoke (ubuntu-latest)` compiles the Linux build on every push, and S5
> captured real ext4/inotify watcher behaviour from a CI runner
> (`docs/spike-results/S5-watcher.md`). What remains genuinely VM-only is font
> rendering for VI/JA, the file dialogs, and the AppImage.

Fresh Ubuntu 24.04 VM (and a 22.04 check for the floor).
**Pass:** debug build launches; bundled Noto fonts render VI/JA correctly;
file/folder dialogs work; watcher fires on ext4; AppImage produced from the
22.04 runner recipe launches on both VMs.

## S4 — Menu bar + shortcuts prototype

> **PASSED — 2026-08-23**, subjective gate included: the maintainer tried the
> prototype and accepted it as-is. Results in
> `docs/spike-results/S4-menubar.md`.
>
> Built on Flutter's Material `MenuBar` rather than hand-rolled: it already is
> the styled widget row doc 06 wanted, and brings arrow traversal and `Esc`
> with it. Two constraints found: a bare `Alt` cannot be a `Shortcuts` entry
> (`SingleActivator` refuses modifier triggers), and the bar cannot be
> *focused* while closed (`ExcludeFocus`), so **`Alt` opens the File menu**
> rather than highlighting it — doc 06 amended. `Alt+F`/`Alt+V`/`Alt+H` work
> through accelerator labels carried in the translated strings.
>
> **No shortcut conflicts on Windows or Linux**, proven by firing every
> activator while a `TextField` holds focus. The `Control`+A/B/E/F/N/T
> collisions exist only on macOS, a v1 non-goal.

Build the custom menu bar skeleton with 5 real items and the doc 06
shortcut set.
**Pass:** full keyboard traversal (Alt, arrows, Esc), no shortcut conflicts
with Flutter defaults, and it *feels* right — subjective gate, Kokone
decides.

## S5 — Watcher save-pattern matrix

> **PASSED on both platforms — 2026-08-23.** Results in
> `docs/spike-results/S5-watcher.md`. Six save patterns reproduced as real
> filesystem operations and observed against the real watcher on Windows/NTFS
> and Ubuntu/ext4 (via a one-off CI job, since S3's VM is deferred). Every one
> normalizes to a single `changed` within 30 ms; the only `missing` is a real
> deletion.
>
> **Classification is by whether the path exists when the debounce window
> closes, never by event kinds** — the first event of "delete + recreate" is
> byte-identical to a real deletion. doc 03 and doc 07 amended.
>
> **One finding changes the design:** `FileWatcher` on Windows is silently
> `PollingFileWatcher` on a one-second timer — 1000 ms against the 500 ms
> budget below. Ad-hoc files are watched through their parent directory
> instead: 7 ms. doc 07 amended.
>
> **Notepad++ confirmed — 2026-08-27.** The maintainer saved a document open in
> MarkLens and the reload was single and immediate, with no `missing` badge
> flashing in between. That could not be checked before M2, because there was
> no watcher running to check it against. VS Code and vim remain unconfirmed,
> and remain a confirmation rather than a risk: all six patterns normalize
> identically, so any answer passes.

Save files from VS Code, Notepad++ and vim on Windows/NTFS; VS Code and vim
on Ubuntu/ext4, against the WatchService normalizer.
**Pass:** every save lands as a single `changed` within 500 ms, or the miss
is documented and caught by the focus-sweep fallback (doc 03). No
false `missing` badges during atomic saves.

## Roadmap

| Milestone | Contents | Est. |
|---|---|---|
| **M0** ✅ | Spikes S1, S2, S4, S5 (S3 deferred), pins locked in doc 01, repo + CI scaffolded with the boundary tests | done 2026-08-23 |
| **M1 — usable daily** ✅ | Open file/folder, sidebar + tabs, pipeline + reader, session restore, single instance + CLI | done 2026-08-26 |
| **M2 — comfortable** ✅ | Watch/auto-reload, outline, Ctrl+F, zoom, themes, front-matter panel — plus the first visual pass's eight defects and the repo's first goldens | done 2026-08-27 |
| **M3 — complete** ✅ | The six items this row used to name, **and the six more the row did not** — images, drag & drop, the update check, About/licenses/log export, Open Recent, and doc 06's edge states. See "M3 build order" | done 2026-08-28 |
| **M4 — shipped** | Packaging both OSes — including wiring M3's file-association assets into the installers — the icon, bundled fonts + renderer goldens, `release.yml`, docs polish, v1.0.0 | 4 wk |

~8.5 focused weeks; solo-dev buffer applies. M1 is the "start living in it"
gate — daily use from M1 onward is the real QA.

**Three of these estimates were written before the milestone was surveyed, and
all three were wrong the same way.** M2 turned out to be mostly wiring, and M3's
row named half its features — its 1.5 wk became 3 wk once the tree was read
against docs 02–11. M4's "1 wk" was the number this table was born with, and it
has now had the survey the other two got too late: **4 wk**, of which roughly
3.5 is coded work and the rest is the clean-VM run, the read-only audit and the
third visual pass, none of which a PR can do. The reasoning is in "M4 build
order" below. The pattern is the point — an unsurveyed estimate in this table
has been wrong every single time, by 2× and then by 4×.

## M1 build order

Dependency order, not preference. What already exists after M0: the renderer
and highlighter behind their seams, the menu bar and the full shortcut set, the
watch normalizer, GitHub heading slugs, UTF-8 decoding, and the torture corpus
with its tests.

1. **Finish `core/markdown/`.** ✅ **Done.** `FrontMatterSplitter`,
   `BlockIndexer`, the parse stage (AST → outline + slugs) and the block-HTML
   pre-pass all shipped together. `MdxSanitizer` is still a pass-through, which
   is M3 and unchanged.

   Three things are worth carrying forward:

   - The block index is built by parsing with position-recording **subclasses**
     of the `markdown` package's own block syntaxes. Wrappers do not work:
     `BlockParser`, `SetextHeaderSyntax` and `HtmlBlockSyntax` all branch on
     the runtime type of a syntax object, so a decorator stops setext headings
     parsing at all. Doc 04 records this.
   - The pre-pass turned out to be a **correctness precondition, not polish**.
     A top-level HTML block is one node to us and zero children to the
     renderer, so `blocks[i] → children[2i]` was already wrong for any document
     containing block HTML. It also rescues block-level `<Component>` tags in
     `.mdx`, which were being deleted the same way — that hole is closed years
     before the sanitizer lands.
   - Two guards carry the risk that nothing else could catch:
     `test/core/parse_mirror_test.dart` compares our parse against the
     renderer's on every fixture, and `test/features/block_alignment_test.dart`
     asserts `children.length == 2N-1` against the real widget — with a
     negative control proving it fails when the pre-pass is switched off.
2. **`core/files/file_service.dart`** ✅ **Done.** Scan, registry, soft cap,
   natural sort, symlinked-directory skip. `OpenedFile` carries two paths —
   a canonical `identity` and a display `path` — because doc 07 asked for a
   canonical identity without noticing it was also the string shown to the
   user. Accepted gap recorded in doc 07: the Windows hidden attribute is not
   honoured, since `FileStat` exposes no attributes.
3. **`core/cache/doc_cache.dart`** ✅ **Done.** LRU of `DocModel`, keyed on
   `identity + mtime + size + settingsRevision`. Docs 02, 03 and 07 each
   specified a different key; that is now reconciled in all four places.
   `settingsRevision` is kept and inert — no v1 setting changes parse output.
4. **`core/session/` and `core/settings/`** ✅ **Done.** Both over one atomic
   `JsonStore` in `core/storage/`, which is why that directory joins the write
   allowlist — with a test asserting it touches nothing outside the `Directory`
   it was handed. Reading is total; corruption and future schemas are
   quarantined rather than deleted. Two ranges added to doc 05
   (`recentLimit`, `sidebarWidth`) with the reasons.
5. **The reader feature** ✅ **Done**, plus File → Open, so the app finally
   opens and shows a document. Two things doc 06 had left undefined were
   settled and written back into it: the **theme tokens** (finalized, with
   their WCAG contrast asserted rather than eyeballed — this also closes S1's
   last open criterion) and the **notice bar** (a slim dismissible bar above
   the document, most serious notice first, the rest counted).

   Note the reader also had to take ownership of the document's selection
   scope. A `SelectionArea` inside the code block would end a drag at the top
   of that block, which is precisely what S2 made a release gate.
6. **Sidebar and tabs** ✅ **Done.** Both are views of one `OpenSet`, and
   neither imports the other. The models live in `core/models/open_set.dart`
   and the controller in `app/`, because a feature may import a model but not
   app state — the same split the theme tokens needed.

   `app/providers.dart` now re-exports the app-level state a feature is
   allowed to see, so `features/` still has exactly one door into `app/`
   while the state stays in the file it belongs to.
7. **`core/single_instance.dart` + CLI args** ✅ **Done**, and with it session
   restore end to end. `no_network_test` had reserved this: its socket
   exception is now one named file rather than a widened token list, and it is
   asserted to bind loopback.

   Two things only a real binary could show. `main` has to `exit()` rather than
   return — the Windows runner creates its window and starts a message loop
   before Dart runs, so `--version` printed and then sat there as a blank
   window. And the session had no save trigger for the open set: a forwarded
   path reached the window and never reached `session.json`. Both are fixed and
   both now have tests.

The M1 gate is the charter's: cold start to restored session under 1.5 s, and
the maintainer using it daily.

**Verified end to end with the real binary, 2026-08-26:** a second launch
naming a file exits 0 while the first stays up, the running window opens that
file and records it, and a relaunch restores it.

### What the first visual pass found

The maintainer ran it and it starts fast. Three things no test caught, because
every one of them is about layout or copy rather than behaviour — worth
recording as the shape of what tests here do *not* cover:

1. **The menu bar is centred, and should be left-aligned.** ✅ Fixed at M2.
   `AppShell`'s `Column` has no `crossAxisAlignment`, so it defaults to
   `center`, and `AppMenuBar` sizes to its content rather than filling —
   Material's `MenuBar` declares no minimum width, so it was the only child of
   that column that shrink-wrapped. `CrossAxisAlignment.stretch` is the whole
   fix. Doc 06's layout diagram puts it at the left.
2. **The status bar is still the S4 prototype line** — `zoom … · sidebar … ·
   outline … · theme …` — where doc 06 specifies `path · position % · word
   count · notices`. ✅ Fixed at M2, all four fields, in
   `features/status/status_bar.dart`. Position % came sooner than expected: it
   only needed the reader to own a `ScrollController` and report a ratio,
   which is a much smaller piece than the scroll-to-block work it was assumed
   to depend on. Word count needed a new pure-Dart stage — see doc 06 for why
   it is not a whitespace split.
3. **A sidebar row truncates its file name too early** (`README....` with room
   to spare). ✅ Fixed at M2. The name and its folder detail were both
   `Flexible` beside a `Spacer` — three flex children of equal weight, so
   `RenderFlex` gave each a third of the row and never redistributed what the
   loose ones left unused. The pair now shares one `Expanded`, inside which the
   folder is a capped non-flexible child laid out first and the name takes the
   rest.

### Five more the same pass turned up

Found while fixing the three, all the same shape — the app not doing what a
doc says, with no test able to notice:

4. **The restored sidebar width had never once been honoured.** `session.json`
   stores `sidebarWidth`, doc 05 clamps it, `SessionLink` restores it — and the
   shell hardcoded `SizedBox(width: 240)`. ✅ Fixed at M2.
5. **The outline panel's title was a hardcoded English literal**
   (`_Panel(label: 'Outline')`), a second rule-4 violation beside the status
   bar. ✅ Fixed at M2 with an ARB key the real panel will keep.
6. **`F11` did not make the window full screen.** It flipped `ChromeState` and
   hid the menu bar; `WindowLink` had no `setFullScreen`, so `window_manager`
   was never told. ✅ Fixed at M2.
7. **Every File menu item was a `todo()` stub** while the identical `Ctrl+O`,
   `Ctrl+R`, `Ctrl+Shift+C` and `Ctrl+W` shortcuts worked — the menu advertised
   behaviour it did not have. ✅ Fixed at M2, in its own PR: behavioural rather
   than visual. The items now go through the same `Actions` map the shortcuts
   use, so the two cannot diverge again. Settings, Open Recent, Check for
   Updates and Export Log keep their placeholders, because those genuinely have
   nothing behind them until M3 — an honest placeholder was never the defect.
8. **The bundled fonts were never added.** `pubspec.yaml` still said they
   "land here at M1"; there is no `fonts/` directory and no `.ttf` in the tree,
   so VI/JA render in whatever the OS supplies — against charter principle 1.
   Not fixed at M2: doc 01's Noto Sans JP size decision is still open and is
   parked at M4 packaging. The stale comment is corrected and the gap is
   recorded here.

### And the first goldens

The lesson of this pass is that 716 tests were strong on what the app *does*
and blind to what it *shows*. `test/goldens/shell_chrome_golden_test.dart`
closes part of that: layout goldens over the menu bar and the status bar, which
also switches on the self-activating CI `golden` job so later goldens are free.
They are generated in a container matching `ubuntu-latest` (`tool/goldens/`),
because the platform that compares them has to be the platform that made them:
generated on Windows first, **four of the five differed from the Ubuntu render
byte-for-byte** while the layout was correct on both. Rasterization, not fonts.

The sidebar row is deliberately covered by ordinary widget tests instead —
asserting the rendered name is as wide as the text it contains, at the width
the sidebar really has. That is font-independent, runs on both platforms, and
states the actual rule rather than a picture of it.

## M2 build order

Six PRs, dependency-ordered. What M2 turned out to be, which the one-line
roadmap entry above does not convey: **mostly wiring.** Almost every surface it
names already had its pure-Dart core, its model, its ARB-labelled menu item and
its keybinding, and no caller at all — `WatchNormalizer`, `Outline`,
`recordScroll`, `SessionDocument.scroll`, `SettingsStore.save`,
`FrontMatterPanel`, every zoom and find activator. The work was finding the
missing caller, not writing the feature.

1. **The visual pass** ✅ — all eight defects, not the three doc 15 listed;
   see "What the first visual pass found" above. Plus the first goldens.
2. **The File menu** ✅ — every item was a `todo()` stub while the identical
   shortcuts worked. Now one `Actions` map serves both.
3. **The settings bridge** ✅ — `settings.json` was read-only at runtime.
   Zoom, theme, `contentMaxWidth` and the front-matter display all persist and
   apply; the duplicated zoom and theme on `ChromeState` are gone rather than
   synchronised.
4. **Scroll to a block** ✅ — the one primitive seven features were waiting
   on. `lib/app/reader_scroll.dart`, no new dependency, measurement plus
   bounded convergence.
5. **The outline panel** ✅ — heading tree, scroll-spy, click to jump.
6. **The watcher** ✅ — `core/watch/watch_service.dart` and the coordinator
   that turns its events into open-set changes, plus doc 03's focus sweep.
7. **Find in file** ✅ — with doc 08 amended: per-match highlighting inside
   rendered prose is not reachable through the renderer, and the measurement is
   recorded in doc 01 beside its other load-bearing behaviours.

Three cross-cutting blockers carried the risk, and none of them appears in the
roadmap line: there was no settings→UI bridge, nothing could scroll to a block,
and nothing started a watcher.

**Still open at the end of M2**, both needing the real binary rather than a
coding session:

- **A second visual pass — done 2026-08-27.** The maintainer ran the binary and
  accepted the chrome, the watcher and every M2 feature. Nothing in these PRs
  changes the fact that layout and copy are what tests here do not see, so the
  pass stays a per-milestone step rather than a one-off; the goldens close a
  slice of it, no more.
- **S5's last item, now partly closed.** Notepad++ was confirmed on
  2026-08-27: single, immediate reload, no `missing` flash. VS Code and vim are
  still unconfirmed. All six patterns normalize identically, so this stays a
  confirmation rather than a risk.

The bundled fonts (defect 8) remain outstanding by decision, not oversight:
doc 01's Noto Sans JP size question is parked at M4 packaging, and the
font-dependent renderer goldens doc 12 describes are blocked behind it.

## M3 build order

**Closed, merged and pushed 2026-08-28** — `origin/main` at `8abb31e`, 1162
tests, up from 847. A fast-forward of eleven commits, one per PR, so `main`'s
history stays one commit per feature exactly as M1 and M2 left it. All six CI
jobs green, `golden (ubuntu)` included.

The first push was **red**, and worth recording because the failure read like a
flake and was not. `test (windows-latest)` failed the MDX quadratic guard,
which asserted five seconds and took 5.22 s — and the cause was a real
quadratic that a local run had never been slow enough to expose. See doc 04,
"the searches for a closing tag share one budget". A marginal timing failure is
a hypothesis about the code before it is a hypothesis about the runner.

Eleven PRs, dependency-ordered. What M3 turned out to be, which the one-line
roadmap entry above did not convey: **the roadmap row named half of it.**
Reading the tree against docs 02–11 before starting found six more features
that are fully specified, have no code, and appear in no milestone row at all —
and since M4 is packaging and the tag, no later milestone covers them.
They are v1 scope by the charter, so they are M3:

| Gap | How it shows up in the tree |
|---|---|
| Images | `_placeholderImage` returns a `Placeholder()` for every image; `flutter_svg` is pinned and imported nowhere; `features/reader/images/` does not exist, though `no_network_test` has reserved that exact path since M0. |
| Drag & drop | `desktop_drop` pinned, imported nowhere. Doc 03 lists it as one of the four open paths; doc 06 wants the drag-over overlay. |
| Update check + banner | `core/update/` does not exist — also a path `no_network_test` has reserved from the start. `network.updateCheck` has no reader in `lib/`. |
| About · licenses · log export | `features/about/` does not exist, and **there is no log ring buffer at all** (doc 02, "Logging"), which is why Export Diagnostic Log has nothing behind it. Help → About is Flutter's bare `showAboutDialog`, without even the version. |
| Open Recent + the recent list | `session.recent` is written and never read back. Worse, `SessionLink._recentPaths` derives it from the *open set*, so closing a file erases it from "recent" — the opposite of what doc 05 specifies. |
| Doc 06 edge states | No missing-file tab body (`ActiveDocument.failedPath` reaches only the status bar), no sidebar context menu, and no `> 50 MB` refusal — `MarkdownPipeline`'s own comment says that last one "belongs to the file service", which does not do it. |

### Three decisions taken before the first PR

- **Full v1 close-out.** All twelve items land in M3. The alternative was an
  M3.5 before the tag, which moves the "complete" gate rather than meeting it.
  The estimate goes from 1.5 wk to 3 wk, and the roadmap row above says so.
- **File association splits.** Doc 11 puts registration in the Inno Setup
  installer and the `.deb`, both of which are M4 work, so M3 cannot own the
  whole item. M3 authors what those installers will *reference* — icons, the
  `.desktop` file, the MIME XML, the `MarkLens.Document` ProgId table — and
  verifies the runtime half, which is single-instance forwarding and already
  works. M4 is then `iscc` and `dpkg-deb` wiring against assets that exist.
- **Rebase-merge, as M2.** Doc 13 says squash, and that rule is paired with
  "PRs small enough to review in one sitting"; `main`'s history is already one
  commit per feature and each PR below is several self-contained ones. Decided
  per milestone rather than settled, so ask again at M4.

### The order

1. **This section** — the milestone written down before eleven PRs cite it.
2. **`MdxSanitizer`** ✅ — the largest piece of new logic, and the only one
   that depends on nothing else. It turned out to be a source-to-source
   rewrite, like `RawBlockRewriter`: doc 04 now records the seven things its
   five transforms did not settle, of which the load-bearing one is that a
   placeholder card does **not** re-render its children — that would nest a
   selection scope inside the reader's, which S2 made a release gate.
3. **Link routing + anchor jumps** ✅, which also built the two primitives
   later PRs need: the `url_launcher` seam and `revealWhenAdopted`, the jump
   that outlives a document switch. Doc 10 invariant 2 is now structural
   rather than a rule to remember — see doc 03. `path` became a direct
   dependency here (rule 10: doc 01 and the notices updated in the same PR).
4. **Images** ✅ — and the corpus earned its keep: the image fixture already
   carried a protocol-relative URL, which reached the *local* branch while
   naming a host. Doc 04 and doc 10 record the rule that was missing.
5. **Cross-file search** (`Ctrl+Shift+F`) ✅ — and doc 08 gains the thing it
   could not have known: a hit read from disk cannot carry a block index,
   because the block index describes `sanitizedSource`. A result carries its
   ordinal, and the click re-finds it in the parsed document.
6. **Quick switcher** (`Ctrl+P`) **and the recent list** ✅, whose first reader
   it is — and which turned out to be broken rather than merely unread: it was
   derived from the open set, so closing a file erased it. Doc 08 records what
   the scorer had to be, and doc 05 what the list now is.
7. **Update check, About, licenses, diagnostic log** ✅ — and doc 10's
   invariant 5 got *stronger* rather than gaining an exception: `file_picker`
   12 writes the exported log itself, so `no_write_test` lost the
   `features/about/` allowlist entry instead of using it.
8. **Settings UI** (`Ctrl+,`) ✅, after 4 and 7 deliberately, so that every
   switch on the screen had something behind it the day it shipped. Three
   settings had no reader at all before it — `language`, `restoreSession` and
   `files.*` — and `restoreSession: false` turned out to need to *freeze*
   `session.json` rather than let it be overwritten, or the switch could not be
   un-flipped. Doc 05 records it. `menuNotImplemented` left the ARB with this
   PR: there is nothing in the app that is not wired.
9. **The shell gaps** ✅ — drag & drop, missing-file body, sidebar context
   menu, the 50 MB refusal. All four had their half already built and no
   caller, which is the M2 pattern one more time. `ExtensionRegistry.parentOf`
   came out of the sidebar's private copy when the missing-file body wanted the
   same answer.
10. **File-association assets** ✅, per the split above — in `packaging/`,
    with doc 11 recording the three things authoring them settled. It also
    surfaced a blocker M4 cannot start without: **there is no MarkLens icon**,
    only the Flutter template's.

    **The runtime half was verified against the real binary, 2026-08-28**, and
    it verified four PRs at once. `marklens.exe probe.md` opened it;
    `marklens.exe second.md` while that was running **exited 0**, left one
    process, and put `second.md` in the running window as the active tab —
    which is exactly what a double-click on an associated file does. Reading
    `session.json` afterwards then showed `recent` populated and ordered
    most-recent-first (PR 6), and `lastUpdateCheck` stamped (PR 7). `--version`
    still prints and exits rather than sitting there as a blank window, which
    is the M1 trap.

    So the only thing standing between here and a working association is the
    installer, which is M4's, and the icon.
11. **i18n vi/ja, the tri-locale pass** ✅, and the note below. vi/ja never
    trailed — every PR translated its own keys, so the release-gate work was
    an *audit* rather than a backlog, and what came out of it is two tests
    that make the audit repeatable.

### What M3 actually was

Eleven PRs, 1161 tests, up from 847 at the end of M2. The one-line roadmap
entry named six of the twelve features; the other six were found by reading the
tree against docs 02–11 before starting, and are listed at the top of this
section.

**The M2 pattern held for a third milestone, and harder.** Almost every feature
here was a missing caller rather than missing code — `Outline.bySlug`,
`MdxSanitizer`, `AppLanguage`, `restoreSession`, `files.extensions`,
`network.*`, `SessionState.recent`, `togglePin`, `failedPath`, `desktop_drop`,
`url_launcher`, `flutter_svg`, `package_info_plus`. Four dependencies had been
pinned since M0 and imported nowhere. The work was finding what was already
waiting, not writing it.

**Two of the orphans were not merely unread — they were wrong**, and only
building a caller could show it. `SessionLink._recentPaths` derived the recent
list from the *open set*, so closing a file erased it: the one thing a recent
list exists for was the one thing it could not do. And `restoreSession: false`
would have overwritten the session it was told not to restore, making the
switch impossible to un-flip.

**Three invariants came out stronger than they went in**, which was not the
plan and is the most useful thing here:

- Doc 10 invariant 2 (no shell-out with document-derived data) stopped being a
  rule and became a type. `ExternalLink` is the only `LinkTarget` carrying a
  `Uri`, and the launcher takes a `Uri` — the check is not a step before the
  shell-out, it is the only thing that can produce its argument.
- Invariant 3 (resource allowlist) took the same shape, with
  `RemoteImageSource` as the only variant carrying a URL.
- Invariant 5 (read-only) **lost an allowlist entry rather than using one**.
  `file_picker` 12's `saveFile` writes the bytes itself, so the diagnostic-log
  export performs no write, and MarkLens's own code now writes nowhere outside
  its config directory.

**The torture corpus earned its keep twice.** The image fixture already carried
a protocol-relative URL, which reached the *local* branch while naming a host —
`File.statSync` on `//example.com/x.png` is Windows opening an SMB connection to
a host the document chose. A UNC path does the same. Both are refused now, in
the link classifier as well as the image one. And the MDX corpus's own prose
turned out to be wrong about its own expectation (`3 imports hidden` for four
statements), which is the kind of thing only running it finds.

**Bugs the tests found that reading did not:** `Uri.decodeComponent` throws on
any code unit above 127, so a Vietnamese anchor took the link classifier down;
a one-letter URI scheme is a Windows drive letter, so `C:/docs/README.md` was
being refused as an unknown protocol on the dev machine's own platform; the
fuzzy scorer charged its gap penalty for characters *after* the last match, so
a match near the start of a long filename lost to a worse one in a short name.

**Verified against the real binary, 2026-08-28.** A second launch naming a file
exits 0 and puts that file in the running window as the active tab — which is
what a double-click on an associated file does — and `session.json` afterwards
shows the recent list and the update stamp. `--version` still prints and exits.

**Still open, and both now blocking M4:**

- **There is no MarkLens icon.** `app_icon.ico` is the Flutter template's and
  no Linux set exists. An installer forces this, because registering a file
  type registers what that type looks like in Explorer.
- **The bundled fonts**, and doc 12's renderer goldens behind them — unchanged
  since M1, parked at M4 packaging by doc 01's open Noto Sans JP size question.
- **The third visual pass** is the maintainer's, and is not something this
  milestone could do for itself. `test/l10n/tri_locale_layout_test.dart` closes
  a slice of it — every M3 surface, in all three locales, at a narrow window,
  asserting nothing overflows — and no more: it cannot see typography, spacing,
  or whether a sentence reads well. M3 added the Settings screen, the About
  dialog, the update banner, the search panel and the quick switcher, all of
  them chrome full of translated text, and layout and copy remain exactly what
  these tests do not see.

### The M2 lesson holds, and is most of the route through

M2 was mostly wiring, and so is much of M3: nearly every surface here already
has its pure-Dart core, its model, its ARB-labelled menu item and its
keybinding, and **no caller**. Before building an M3 feature, look for the
missing caller. Verified at the start of M3:

- `Outline.bySlug` — no caller anywhere. It *is* anchor jumps.
- `MdxSanitizer.sanitize` returns its input unchanged, and says so in its own
  doc comment.
- `AppLanguage` has no reader: `MarkLensApp` sets `supportedLocales` and **no
  `locale:`**, so the language setting has never once done anything.
- `AppSettings.restoreSession` has no reader; the cold start restores
  unconditionally.
- `files.extensions` and `files.fileCap` never reach `FileService`, which is
  constructed as `const FileService()` with its defaults.
- `network.allowRemoteImages` and `network.updateCheck` have no readers.
- `OpenSetController.togglePin` has no caller from the sidebar.
- `Ctrl+P`, `Ctrl+Shift+F` and `Ctrl+,` are the last three `_todo()` stubs in
  `app/app.dart`.

### Deliberately not M3

The bundled fonts and the renderer goldens behind them stay parked at M4
packaging, where doc 01's Noto Sans JP size question closes. S3's clean-VM run
was already deferred to the M4 release checklist. Installer wiring is M4 by the
decision above.

## Start M4 here

M3 merged to `main` on 2026-08-28 as eleven commits (`1be9c89`), 1161 tests.
Everything in the charter's v1 scope now exists; M4 is turning it into
artefacts. Surveyed at the close of M3:

- **Two things block packaging before any of it can start**, and both are
  decisions somebody has to make rather than code somebody has to write:
  - **There is no MarkLens icon.** `windows/runner/resources/app_icon.ico` is
    the Flutter template's, there is no `linux/` icon set, and `packaging/`
    names `marklens` as the icon while shipping none. An installer forces this
    rather than tolerating it: registering a file type registers what that type
    looks like in Explorer and in a file manager, which is the first thing
    anyone sees of this program.
    **Closed at M4** — `icon/marklens.svg` is the master and
    `tool/icons/render_icon.py` generates the rest (doc 11).
  - **The bundled fonts**, on doc 01's open Noto Sans JP size question. There
    is no `fonts/` directory and no `fonts:` entry in `pubspec.yaml`, so VI/JA
    render in whatever the OS supplies — against charter principle 1. Doc 12's
    renderer goldens are blocked behind it, and are still the only kind of
    golden this repo does not have.
    **Closed at M4** — subset to JIS X 0208, +5.19 MiB on the artefact, with
    the two rejected alternatives and their numbers in doc 01 and
    `fonts/README.md`. The renderer goldens followed immediately, so the repo
    now has both kinds doc 12 describes.
- **`packaging/` is authored and wired to nothing.** The ProgId table, the
  `.desktop` entry and the MIME XML are there with their reasons; no installer
  script, `CMakeLists` or workflow reads them. That is M4's first mechanical
  job and it is deliberately small.
- **There is no `release.yml`.** Doc 14 describes the caller stub and the three
  jobs; `.github/workflows/` has `ci.yml` and `watch-observation.yml` only.
  Action A-1 — contributing `reusable-flutter-ci.yml` and
  `reusable-flutter-release.yml` to `poli0981/.github` — is also untouched, and
  doc 14 says the inline jobs were written lift-and-shift-ready for it.
  **A-1 is now dropped from v1** — see "M4 build order", decision 5.
- **S3's clean-VM run** has been deferred since M0 and lands here, where it was
  always scheduled. What is genuinely VM-only is unchanged: font rendering for
  VI/JA, the file dialogs, and whether the AppImage launches.
- **`--version` and single-instance forwarding are verified** against the real
  binary (2026-08-28), so the runtime half of file association needs nothing
  from M4 but the registration.
- **The third visual pass is unrun**, and is the largest thing M4 inherits that
  no test can do for it. M3 added the Settings screen, About, the update
  banner, the search panel and the quick switcher — all chrome, all translated.
  `test/l10n/tri_locale_layout_test.dart` proves none of them *overflow* in
  three locales; it says nothing about whether any of them look right.

The merge was a fast-forward, so `main`'s history stays one commit per feature.
Doc 13's squash rule was waived for M2 and M3 on that basis — **ask again
before M4's first PR** rather than assuming a third time. **Asked and answered:**
rebase again for M4, and doc 13 now records what three milestones in a row
actually mean.

## M4 build order

Sixteen PRs, dependency-ordered. Written down before any of them cite it, which
is the one habit from M3 worth keeping unchanged.

What the survey found, which the one-line roadmap entry did not convey: **M4 is
not "wiring" the way M2 and M3 were.** Those milestones kept finding features
that were already built and had no caller. M4 finds the opposite — three things
that were deliberately *not* built, each parked behind a decision nobody had
made, plus a release pipeline that exists only as prose in doc 14. There is no
missing caller to find. Everything here has to be authored.

### Five decisions taken before the first PR

- **The bundled Noto Sans JP is subset**, to kana + JIS X 0208 + CJK
  punctuation + fullwidth forms. Doc 01 has held this question open since M0 and
  asked for "real numbers before M4 packaging"; the number and the accepted
  coverage gap close in doc 01 §Bundled fonts, beside the highlighter's accepted
  gaps, in the same shape. The subsetting command and the upstream version it
  ran against are recorded in `fonts/README.md`, because a subset that cannot be
  reproduced will silently change glyph coverage the next time somebody
  regenerates it — and every renderer golden with it.
- **The icon is derived from one master**, which the maintainer supplies.
  `icon/icon-512.ico` is a proper multi-size ICO but its largest frame is 256
  (the format's maximum), so despite the name it cannot produce the 512 a Linux
  hicolor set wants. A committed master plus a recorded regeneration command
  makes the icon set a *derivative* rather than nine binary files nobody can
  account for — the `tool/goldens/` arrangement, one directory over.
- **Rebase-merge, as M2 and M3.** Doc 13 records why, and now also records that
  three milestones in a row is a pattern rather than three exceptions. Ask again
  at M5 rather than assuming a fourth time.
- **M4 ends at a draft release.** `release.yml` always produces a draft; the
  publish is a human click after the clean-VM smoke, the read-only audit and the
  third visual pass. That is doc 14's own split, and it is the only arrangement
  in which the manual half of the release checklist has to actually happen.
- **Action A-1 is dropped from v1.** Doc 14's house pattern is a thin caller stub
  delegating to `poli0981/.github`; that repo is real and public, carries twelve
  `reusable-*.yml`, and has no Dart/Flutter stack. Contributing one is an
  ops-repo project, not a MarkLens release blocker, and doing it *before* this
  repo has ever run a release workflow would mean designing a reusable interface
  against zero experience of the thing it abstracts. The inline workflows stay,
  and doc 14 says so rather than continuing to describe a shape the repo does
  not have.

### Two findings that changed the release design

Both are about the ground moving under a doc that was correct when written.

1. **`ubuntu-22.04` runners begin deprecation on 2026-09-17 and are fully
   unsupported by 2027-04-17.** Doc 14 builds the Linux artefacts there
   "deliberately the floor image", and the charter's platform floor is Ubuntu
   22.04 — so following doc 14 literally gives a release pipeline with a seven-
   month life. The artefacts are therefore built **in an `ubuntu:22.04`
   container on an `ubuntu-24.04` runner**: the glibc floor becomes a property
   of an image we pin rather than of a runner label somebody else retires, and
   it reuses the container arrangement `tool/goldens/` already proved.
2. **`-latest` labels drift, and goldens are the thing that notices.**
   `ubuntu-latest` is 24.04 today, ubuntu-26.04 images already exist, and
   `windows-latest` has just moved to a VS2026 image. The `golden` job runs on
   `ubuntu-latest` while `tool/goldens/Dockerfile` says `FROM ubuntu:24.04`; the
   day those diverge, every golden fails byte-for-byte at once with nothing
   wrong in the layout. That failure has already happened once here, generated
   on Windows against an Ubuntu reference, and it was rasterization rather than
   fonts. So `golden` pins `ubuntu-24.04`, the Windows release job pins
   `windows-2025`, and a test asserts the job image and the Dockerfile agree.

### The order

1. **This section**, plus the roadmap estimate it corrects and doc 13's
   merge-strategy answer.
2. **The stray golden failures.** Twelve `test/goldens/failures/*.png` are
   tracked, from the M2 settings PR; they are Flutter's failure dump, not source.
   Deleted, gitignored, and the `golden` job gains a `git status --porcelain`
   check — which catches the more valuable case too, a golden that was never
   regenerated.
3. **`package_info_plus` leaves.** Pinned since M0, imported nowhere: the version
   comes from `lib/app/version.dart` because `--version` runs before a Flutter
   binding exists. Rule 10 runs in both directions, so doc 01 and the notices
   lose a row in the same PR — and doc 11 §Versioning stops claiming a mechanism
   the app has never used.
4. **CI: the image pins, the lockfile cache, and A-1's removal from doc 14.**
   Plus `test/repo/pin_agreement_test.dart` — the Flutter pin lives in four
   places (`ci.yml`, `watch-observation.yml`, `tool/goldens/Dockerfile`, doc 01)
   and doc 01's "must never disagree" is a rule nobody can enforce by reading.
   It becomes a check. `test/repo/` is a new family, deliberately outside
   `test/architecture/`: those tests are about the app's boundaries, these are
   about the repo's agreements with itself.
5. **The icon**, per the decision above. Blocked until the master lands.
6. **The product strings.** `Runner.rc` says `marklens` in lowercase and both
   window titles do too, so the taskbar, alt-tab and Explorer's Description
   column all say something that is not the program's name. `LegalCopyright`
   says "All rights reserved" on a GPL-3.0-only binary, which is not a
   capitalisation nit but a false licence statement inside the exe. And
   `StartupWMClass=marklens` has never matched: GTK takes the WM class from
   `g_get_prgname()`, which `my_application.cc` sets to `APPLICATION_ID`.
7. **The fonts** — bytes and licensing only, no pixel changes. Including
   `legal/licenses/`, which the notices' own release gate has required since M0
   and which does not exist, and an explicit `LicenseRegistry.addLicense` for
   the OFL: `showLicensePage` collects package licences automatically and asset
   licences not at all, so without it the three fonts we ship appear nowhere.
8. **The typography seam**, separately, so that the golden diff has exactly one
   cause. Three identical `fontFamily: 'monospace'` literals collapse into one
   source reached through `app/providers.dart` — the door features are already
   allowed, rather than a widened architecture-test allowlist.
9. **The renderer goldens** doc 12 has described since M0 and been blocked on
   since M1. The VI and JA pages are the whole justification for the fonts, and
   the only mechanical check that the JP subset covers what the app actually
   renders.
10. **The Inno main script and the portable zip.**
11. **The `.deb`.**
12. **The AppImage.**
13. **`release.yml`**, `SHA256SUMS`, and the draft.
14. **The integration smoke** doc 12 lists as release-blocking and nobody wrote.
15. **The README and everything that still says M0.**
16. **v1.0.0** — the version in its three places, and the CHANGELOG.

### What only a person can do

Unchanged from what "Start M4 here" inherited, and none of it is a PR: S3's
clean-VM run, the Process Monitor / `strace` read-only pass, the third visual
pass, and the listings.

One checklist item deserves naming now rather than being discovered on release
day. **"Update banner fires from the previous version" cannot be met at
v1.0.0**, because there is no previous version — this repo has zero tags. The
honest options are to defer the item to v1.0.1, to publish a throwaway earlier
tag purely to have something to upgrade *from*, or to run a locally-built binary
with a lower `appVersion` against the real published release. Whichever is
chosen, the checklist should say so; an item that cannot be ticked is worse than
one that is deferred, because it teaches everyone to skip the list.

## Release checklist (every tag)

- [ ] Version bumped in `pubspec.yaml`; CHANGELOG section written
- [ ] Full suite green incl. goldens + integration on both runners
- [ ] vi/ja translations complete for new strings
- [ ] Read-only audit: write-grep test green + manual ProcMon/strace pass (doc 10)
- [ ] Artifacts smoke-tested on clean Windows VM + Ubuntu 24.04 VM
- [ ] `SHA256SUMS` verified; release notes written; tag `vx.y.z`; publish draft
- [ ] Listings updated: SoftHarbor entry + poli0981.dev portfolio
- [ ] Post-release: file association behaves after real install; update
      banner fires from the previous version
