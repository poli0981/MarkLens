# 15 · P0 spikes & roadmap

Feature work does not start until the spikes that *gate design decisions*
pass. Each spike is a throwaway branch with a written result note committed to
`docs/spike-results/`.

**As of 2026-08-23: S1, S2, S4 and S5 have passed and M0 is closed.** S3 is
deliberately deferred — see below. Every decision they settled is recorded in
doc 01 (pins), doc 03 and doc 07 (watching), doc 04 (pipeline) and doc 06
(selection, menu bar).

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
> Still open, and a confirmation rather than a risk: *which* editor uses
> *which* pattern. All six normalize identically, so any answer passes.

Save files from VS Code, Notepad++ and vim on Windows/NTFS; VS Code and vim
on Ubuntu/ext4, against the WatchService normalizer.
**Pass:** every save lands as a single `changed` within 500 ms, or the miss
is documented and caught by the focus-sweep fallback (doc 03). No
false `missing` badges during atomic saves.

## Roadmap

| Milestone | Contents | Est. |
|---|---|---|
| **M0** ✅ | Spikes S1, S2, S4, S5 (S3 deferred), pins locked in doc 01, repo + CI scaffolded with the boundary tests | done 2026-08-23 |
| **M1 — usable daily** | Open file/folder, sidebar + tabs, pipeline + reader, session restore, single instance + CLI | 2 wk |
| **M2 — comfortable** ✅ | Watch/auto-reload, outline, Ctrl+F, zoom, themes, front-matter panel — plus the first visual pass's eight defects and the repo's first goldens | done |
| **M3 — complete** | Cross-file search + Ctrl+P, MDX placeholders, link routing, file association, Settings UI, i18n vi/ja | 1.5 wk |
| **M4 — shipped** | Packaging both OSes, A-1 reusable workflow, docs polish, v1.0.0 | 1 wk |

~7 focused weeks; solo-dev buffer applies. M1 is the "start living in it"
gate — daily use from M1 onward is the real QA.

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

- **A second visual pass.** The first one is what produced this milestone's
  opening work, and nothing in these six PRs changes the fact that layout and
  copy are what tests here do not see. The goldens close a slice of it, no more.
- **S5's last item.** Which editor performs which save pattern — save from VS
  Code, Notepad++ and vim with a document open and confirm the reload is single
  and prompt. All six patterns normalize identically, so it is a confirmation
  rather than a risk, but until M2 there was no watcher to confirm it against.

The bundled fonts (defect 8) remain outstanding by decision, not oversight:
doc 01's Noto Sans JP size question is parked at M4 packaging, and the
font-dependent renderer goldens doc 12 describes are blocked behind it.

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
