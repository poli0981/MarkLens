# 10 · Security & privacy

## Threat model

- **Untrusted input:** every opened file. A `.md`/`.mdx` from a cloned repo,
  a download, an email attachment may be adversarial — crafted to crash the
  parser, to execute (MDX/HTML/scripts), or to exfiltrate (remote resources
  as tracking beacons).
- **Assets to protect:** the user's filesystem integrity (read-only
  promise), their privacy (what they read is nobody's business), and app
  availability (no file may DoS the viewer).

## Invariants (release-gating)

1. **No execution.** MDX is sanitized to placeholders (doc 04); HTML is
   never interpreted; there is no webview, no JS engine, no `eval`-like
   path. Dependency review at every upgrade confirms none sneaks in
   transitively.
2. **No shell-outs with document-derived data.** External links go through
   `url_launcher` only after an `http/https` scheme check; `file:`,
   `javascript:`, custom schemes are refused with a notice. Document content
   never reaches a process argument.

   **Made structural at M3**, rather than left as a rule to remember:
   `classifyLink` in `core/links/` returns a sealed `LinkTarget`, and
   `ExternalLink` is the only variant carrying a `Uri`. `LauncherLink.open`
   takes a `Uri`. So the check is not a step that precedes the shell-out — it
   is the only thing that can produce the argument the shell-out needs. The
   renderer seam is narrowed to match: it passes the href and neither the link
   text nor its title, so there is no document text on that path at all.
   `test/core/link_target_test.dart` fires thirteen schemes at it, and
   `test/app/link_routing_test.dart` taps a `javascript:` link in a rendered
   document and asserts the launcher was never called.
3. **Resource loading allowlist.** Images only, local only by default,
   extension-checked, size-capped (doc 04). A document cannot make the app
   read arbitrary non-image files into memory for display.

   **Structural at M3**, the same way invariant 2 is: `classifyImage` returns a
   sealed `ImageSource`, and `RemoteImageSource` is the only variant carrying a
   `Uri` — so the widget that can make a request cannot be built from anything
   else. Two `src` shapes turned out to reach the *local* branch while naming a
   host, and both are refused: a protocol-relative URL and a UNC path. See
   doc 04.
4. **Zero network by default.** Exactly two opt-in-controlled calls exist:
   - Update check (default on, off-switch in Settings): HTTPS to
     `api.github.com`, sends nothing but the request itself.
   - Remote images (default **off**): requests go to whatever host the
     document names — this is precisely a tracking-beacon vector, which is
     why the default is off and the placeholder shows the URL.
   Nothing else. No telemetry, no crash reporting, no analytics, ever.

   Enforced by `test/architecture/no_network_test.dart`, which fails on
   `HttpClient`, `package:http`, `Socket.connect`, `Image.network`,
   `NetworkImage` or `SvgPicture.network` outside `core/update/` and the
   remote-image path. This matters concretely: `flutter_svg` pulls `http`
   transitively (doc 01), so a network-capable API is sitting in the binary
   one autocomplete away from being used by accident.
5. **Read-only enforcement.** The only `File`/`IOSink` writes in the codebase
   live in SessionStore/SettingsStore and the single-instance lock — **all
   inside the config directory**. `test/architecture/no_write_test.dart`
   asserts no other write-mode file opens exist; a manual Process Monitor
   (Windows) / `strace` (Linux) pass is on the release checklist.

   **Stronger since M3.** This used to end "and the user-pointed log export",
   with `lib/features/about/` allowlisted for it. `file_picker` 12's `saveFile`
   takes the bytes and writes them itself, so the export hands over an encoded
   string and performs no write at all — the allowlist entry was **removed**
   rather than used, and MarkLens's own code now writes nowhere outside its
   config directory. The export is still the only way a log entry leaves the
   process, and it still takes an explicit action every time.
6. **Crash-resistance.** Torture corpus (doc 12) includes malformed UTF-8,
   pathological nesting, gigantic tables, adversarial MDX. Parser exceptions
   degrade to plain text (rule 9).

## Privacy posture

All state is local (doc 05). File paths appear in the session file and the
in-memory log ring buffer — both on the user's own disk/RAM, exported only
by explicit user action. The privacy policy (`legal/PRIVACY.md`) is short
because there is genuinely nothing collected.

## Supply chain

Exact pins + committed lockfile (doc 01); monthly batch upgrades with
license + changelog review; pub.dev packages run no install scripts, which
keeps the attack surface at "code we ship", reviewable. CI actions are
pinned per house convention (doc 14).

## Reporting

Vulnerabilities → `SECURITY.md` (private report, 90-day coordinated
disclosure). Crafted-file crashes and any violation of invariants 1–5 are
explicitly in scope and treated as security bugs, not ordinary bugs.
