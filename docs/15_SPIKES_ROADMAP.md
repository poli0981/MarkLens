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
> Still open: the doc 06 styling-token check (blocked until M1 defines the
> tokens) and the highlighter decision. **No pin has moved in doc 01**, because
> S2 below is a "fail here = revisit S1" gate and Q3 has already shown
> selection over a lazy list does not work as specified.

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
| **M2 — comfortable** | Watch/auto-reload, outline, Ctrl+F, zoom, themes, front-matter panel | 1.5 wk |
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
2. **`core/files/file_service.dart`** — open/scan, extension registry, the
   1,000-entry cap, natural sort, symlink-dir skip (doc 07). Everything that
   opens anything needs it.
3. **`core/cache/doc_cache.dart`** — LRU of `DocModel`, keyed on
   `path + mtime + settingsRevision`.
4. **`core/session/` and `core/settings/`** — versioned JSON, atomic writes,
   corruption recovery (doc 05). Both take the config `Directory` as a
   constructor argument; `app/providers.dart` resolves it.
5. **The reader feature** — `DocModel` through `MarkdownRenderer`, front-matter
   panel, notice bar.
6. **Sidebar and tabs**, talking to each other only through
   `app/providers.dart`.
7. **`core/single_instance.dart` + CLI args** in `main.dart`, then session
   restore end to end — the last piece, because it needs all of the above.

The M1 gate is the charter's: cold start to restored session under 1.5 s, and
the maintainer using it daily.

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
