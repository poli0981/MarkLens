# Bundled fonts

Generated. Do not edit, and do not add a file here by hand — `pubspec.yaml` and
this directory are written together by:

```bash
python tool/fonts/build_fonts.py
```

The script downloads pinned upstream releases into `build/fonts-src/`
(gitignored), verifies each by SHA-256, subsets them, and writes the eight files
beside this README.

**The output is byte-reproducible**, and that took one fix to be true.
`fontTools` stamps `head.modified` on save unless told not to, so two runs a
second apart produced eight files of identical length differing in three bytes
each — the timestamp and the checksums that follow it. That is 5.4 MB of binary
churn in git for a rebuild that changed no glyph, in files no reviewer can read
a diff of. `TTFont(..., recalcTimestamp=False)` fixes it; setting the
subsetter's own `recalc_timestamp` option is *not* enough, because the font
object does the stamping. Verified by running the build twice and comparing.

`test/app/fonts_test.dart` asserts that what is declared and what is on disk
agree **in both directions** — a declared file that is missing throws only when
something asks for that weight, and an undeclared file here ships in every
artefact forever.

## Sources, pinned

| Upstream | Pin | Files taken |
|---|---|---|
| `notofonts/notofonts.github.io` | commit `3a06b1c5` | `NotoSans-{Regular,Bold,Italic,BoldItalic}.ttf`, hinted |
| `notofonts/noto-cjk` | tag `Sans2.004` | `Sans/SubsetOTF/JP/NotoSansJP-{Regular,Bold}.otf` |
| `JetBrains/JetBrainsMono` | tag `v2.304` | `fonts/ttf/JetBrainsMono-{Regular,Bold}.ttf` |

Noto Sans is pinned by **commit** rather than by branch because
`notofonts.github.io` is a rolling distribution repo with no per-family tags: a
branch name would silently change what "the" font is between two runs. The
release zip for the same family is 117 MB — every script, weight and format —
so the four files are fetched individually instead, and the whole download is
about 17 MB.

Versions as the fonts themselves report them (`name` table, not the tag):
Noto Sans **2.015**, Noto Sans JP **2.004**, JetBrains Mono **2.304**.

## What the subset keeps

**Latin faces** — Basic Latin, Latin-1 Supplement, Latin Extended-A and -B,
Combining Diacritical Marks, **Latin Extended Additional** (where Vietnamese
precomposed forms live), General Punctuation, Currency Symbols, Arrows,
Mathematical Operators, Box Drawing, Geometric Shapes and Miscellaneous Symbols.

Ranges rather than a scan of our own strings, because the UI is translated and
a user's *document* is not: a Vietnamese README this repo has never seen still
has to render. Combining marks are in because doc 04's slug algorithm already
met decomposed Vietnamese in the wild.

**Japanese** — the **JIS X 0208** repertoire, which is 6,879 characters against
the 20,992 a `U+4E00..U+9FFF` block range would have taken.

The list is derived, not written down: every two-byte Shift-JIS sequence is
decoded with the standard library's `shift_jis` codec and whatever decodes is
in. `shift_jis` rather than `cp932` — the latter adds NEC and IBM vendor rows
that are not part of the standard.

**Both** also union in every character in `lib/l10n/*.arb` and the whole
`test/fixtures/torture/` corpus. A subset missing one kanji that `app_ja.arb`
uses renders a tofu box, and nothing in this repo could see it; including the
sources directly is cheaper than hoping. Measured: the app and corpus use 519
characters outside the Latin ranges, and **zero** JIS level-2 kanji.

`test/goldens/renderer_golden_test.dart` is what actually checks the union held
— its Japanese page would show a tofu box for any kanji the subset missed.

## The numbers doc 01 asked for

| File | Upstream | Subset | Kept |
|---|---:|---:|---:|
| `NotoSans-Regular.ttf` | 621,572 | 179,680 | 28.9% |
| `NotoSans-Bold.ttf` | 631,484 | 183,872 | 29.1% |
| `NotoSans-Italic.ttf` | 639,124 | 186,484 | 29.2% |
| `NotoSans-BoldItalic.ttf` | 646,092 | 188,804 | 29.2% |
| `NotoSansJP-Regular.otf` | 4,533,028 | 2,153,376 | 47.5% |
| `NotoSansJP-Bold.otf` | 4,656,448 | 2,212,436 | 47.5% |
| `JetBrainsMono-Regular.ttf` | 273,900 | 167,964 | 61.3% |
| `JetBrainsMono-Bold.ttf` | 277,828 | 171,012 | 61.6% |
| **Total** | **12,279,476** | **5,443,628** | **44.3%** |

Effect on the artefact, measured on a clean Windows release build:
**33,910,661 → 39,352,134 bytes, +5.19 MiB, +16.0%.**

## Two alternatives, also measured

Recorded because doc 01 asked for a decision made on numbers, and a number
without its alternatives is not one.

| Option | Saves | Costs |
|---|---:|---|
| **JIS level 1 only** (drop the 3,390 level-2 kanji) | 2.03 MB | Level-2 kanji fall through to the system font — which is exactly the OS-dependent rendering the bundle exists to remove |
| **Drop `NotoSansJP-Bold`** | 2.21 MB | Every heading in a Japanese document gets synthesised bold |

Neither was taken. The first loses on charter priority: principle 1 (identical
rendering on both OSes) outranks principle 5 (small), and a subset that drops
half the standard's kanji re-opens the hole the bundle was added to close.

The second is a closer call and is genuinely about quality rather than
correctness — synthesised bold is deterministic, so it would not break
principle 1. It was rejected because a *reading* application shows bold Japanese
in every heading of every document, and 2.21 MB on a 39 MB artefact is not the
place to economise. If that judgement is ever revisited, the number is here and
the change is one line in `build_fonts.py`.

## Licensing

All three are SIL OFL-1.1, and the OFL requires its text to travel with the
font. `legal/licenses/OFL-1.1-*.txt` ship in the bundle via `pubspec.yaml`'s
`assets:`, and `lib/app/license_registry.dart` registers them with
`LicenseRegistry` — which collects *package* licences automatically and asset
licences not at all, so without that call the three fonts we ship would appear
nowhere in the app.

Copyright lines, read from each font's own `name` table:

- Noto Sans — Copyright 2022 The Noto Project Authors
- Noto Sans JP — © 2014–2021 Adobe (http://www.adobe.com/)
- JetBrains Mono — Copyright 2020 The JetBrains Mono Project Authors
