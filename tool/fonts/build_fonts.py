#!/usr/bin/env python3
"""Download the three upstream fonts, subset them, and write `fonts/`.

Run from the repo root:

    python tool/fonts/build_fonts.py

Sources are pinned by commit or release tag *and* verified by SHA-256, and the
originals are cached under `build/fonts-src/` (gitignored) so a second run does
no network I/O. Only the subset output is committed.

Needs `fonttools` on the machine running it. Like Pillow in `tool/icons/`, it is
a dev-machine tool and never reaches `pubspec.yaml`.

Why subset at all: doc 01 has held the Noto Sans JP size question open since M0
- "several MB, and pushes directly against charter principle 5 (Small - in
download size)" - and asked for real numbers before M4 packaging. A full
NotoSansJP-Regular is 4.5 MB and Bold another 4.7 MB, on a Windows release
bundle that is 33.9 MB in total. Subsetting to the JIS X 0208 repertoire is the
answer that keeps identical VI/JA rendering on both OSes (charter principle 1)
without paying nine megabytes for kanji no Japanese document in this decade
uses.

The kanji list is not hand-written and not a Unicode block range. Enumerating
U+4E00..U+9FFF would take 20,992 ideographs where JIS X 0208 defines 6,355. So
the repertoire is *derived*: every two-byte Shift-JIS sequence is decoded with
the standard library's `shift_jis` codec - which is JIS X 0208 plus JIS X 0201
and, unlike `cp932`, carries no vendor extensions - and whatever decodes is in.
That is reproducible, needs no data file, and says exactly what it means.

On top of that the subset unions in **every character the app itself can
display**: all three ARB files and the whole torture corpus. A subset missing
one kanji used in `app_ja.arb` renders a tofu box, and no test in this repo
could see it - the renderer goldens in the next PR are the first thing that
could, and only for the pages they cover. Including the sources directly is
cheaper than hoping.
"""

from __future__ import annotations

import hashlib
import io
import os
import sys
import urllib.request
import zipfile
from typing import Final

from fontTools import subset
from fontTools.ttLib import TTFont

REPO_ROOT: Final[str] = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..")
)
CACHE: Final[str] = os.path.join(REPO_ROOT, "build", "fonts-src")
OUT: Final[str] = os.path.join(REPO_ROOT, "fonts")

# Pinned by commit SHA rather than by branch: `notofonts.github.io` is a rolling
# distribution repo with no per-family tags, so a branch name would silently
# change what "the" font is between two runs of this script.
NOTO_SANS_COMMIT: Final[str] = "3a06b1c521155492df224d33464b3c7b2852d861"
NOTO_CJK_TAG: Final[str] = "Sans2.004"
JETBRAINS_TAG: Final[str] = "v2.304"

# (destination filename, url, sha256). Every byte this script fetches is here.
SOURCES: Final[tuple[tuple[str, str, str], ...]] = (
    (
        "NotoSans-Regular.ttf",
        f"https://raw.githubusercontent.com/notofonts/notofonts.github.io/{NOTO_SANS_COMMIT}/fonts/NotoSans/hinted/ttf/NotoSans-Regular.ttf",
        "478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823",
    ),
    (
        "NotoSans-Bold.ttf",
        f"https://raw.githubusercontent.com/notofonts/notofonts.github.io/{NOTO_SANS_COMMIT}/fonts/NotoSans/hinted/ttf/NotoSans-Bold.ttf",
        "1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913",
    ),
    (
        "NotoSans-Italic.ttf",
        f"https://raw.githubusercontent.com/notofonts/notofonts.github.io/{NOTO_SANS_COMMIT}/fonts/NotoSans/hinted/ttf/NotoSans-Italic.ttf",
        "467e3f89eeca4108bb8710a2b9e0cf2281ac56d5b0609211a83776d0505eecb5",
    ),
    (
        "NotoSans-BoldItalic.ttf",
        f"https://raw.githubusercontent.com/notofonts/notofonts.github.io/{NOTO_SANS_COMMIT}/fonts/NotoSans/hinted/ttf/NotoSans-BoldItalic.ttf",
        "1b602a9d6353be42c91df097a4857b69fa2696f26703d7a33b54a15d87c2622c",
    ),
    (
        "NotoSansJP-Regular.otf",
        f"https://raw.githubusercontent.com/notofonts/noto-cjk/{NOTO_CJK_TAG}/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf",
        "dff723ba59d57d136764a04b9b2d03205544f7cd785a711442d6d2d085ac5073",
    ),
    (
        "NotoSansJP-Bold.otf",
        f"https://raw.githubusercontent.com/notofonts/noto-cjk/{NOTO_CJK_TAG}/Sans/SubsetOTF/JP/NotoSansJP-Bold.otf",
        "1b0edfb500b73a4fa8a4fcaae1bbbd403994e08e73e3e0da37e70d3853f42c5f",
    ),
    (
        "JetBrainsMono-2.304.zip",
        f"https://github.com/JetBrains/JetBrainsMono/releases/download/{JETBRAINS_TAG}/JetBrainsMono-2.304.zip",
        "6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf",
    ),
)

# Members lifted out of the JetBrains Mono archive, which ships nine weights.
JETBRAINS_MEMBERS: Final[dict[str, str]] = {
    "fonts/ttf/JetBrainsMono-Regular.ttf": "JetBrainsMono-Regular.ttf",
    "fonts/ttf/JetBrainsMono-Bold.ttf": "JetBrainsMono-Bold.ttf",
    "OFL.txt": "JetBrainsMono-OFL.txt",
}


def _fetch(name: str, url: str, digest: str) -> str:
    """Download `url` to the cache unless a byte-identical copy is there."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if os.path.exists(path) and _sha256(path) == digest:
        return path

    print(f"  fetching {name} ...", flush=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        blob = response.read()

    actual = hashlib.sha256(blob).hexdigest()
    if actual != digest:
        raise SystemExit(
            f"{name}: sha256 mismatch\n  expected {digest}\n  got      {actual}\n"
            "The pin moved, or the download is not what it claims to be. Do not "
            "just update the constant - find out which."
        )
    with open(path, "wb") as handle:
        handle.write(blob)
    return path


def _sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def jis_x_0208() -> set[str]:
    """The JIS X 0208 repertoire, derived rather than listed.

    Every valid two-byte Shift-JIS sequence, decoded. `shift_jis` rather than
    `cp932`: the latter adds NEC/IBM vendor rows that are not part of the
    standard and would grow the subset for characters a document is unlikely to
    contain.
    """
    characters: set[str] = set()
    for lead in list(range(0x81, 0xA0)) + list(range(0xE0, 0xF0)):
        for trail in range(0x40, 0xFD):
            if trail == 0x7F:
                continue
            try:
                characters.add(bytes((lead, trail)).decode("shift_jis"))
            except UnicodeDecodeError:
                continue
    # JIS X 0201: ASCII plus half-width katakana, both single-byte.
    for byte in list(range(0x20, 0x80)) + list(range(0xA1, 0xE0)):
        try:
            characters.add(bytes((byte,)).decode("shift_jis"))
        except UnicodeDecodeError:
            continue
    return characters


def app_characters() -> set[str]:
    """Every character the app's own strings and test corpus can display."""
    characters: set[str] = set()
    roots = (
        os.path.join(REPO_ROOT, "lib", "l10n"),
        os.path.join(REPO_ROOT, "test", "fixtures", "torture"),
    )
    for root in roots:
        for directory, _, files in os.walk(root):
            for name in files:
                if not name.endswith((".arb", ".md", ".mdx", ".json")):
                    continue
                path = os.path.join(directory, name)
                with open(path, "rb") as handle:
                    # errors="ignore": the corpus deliberately contains
                    # malformed UTF-8, and a decoder that raised here would make
                    # the font depend on which fixtures happen to be valid.
                    characters.update(handle.read().decode("utf-8", "ignore"))
    return characters


def latin_characters() -> set[str]:
    """Latin, Latin-1 Supplement, Latin Extended-A/B and Vietnamese.

    Ranges rather than a corpus scan, because the UI is translated and a user's
    *document* is not: a Vietnamese README this repo has never seen still has to
    render. Latin Extended Additional (U+1E00..U+1EFF) is where most Vietnamese
    precomposed forms live, and combining marks are included because doc 04's
    slug algorithm already found decomposed Vietnamese in the wild.
    """
    ranges = (
        (0x0020, 0x007E),  # Basic Latin
        (0x00A0, 0x00FF),  # Latin-1 Supplement
        (0x0100, 0x017F),  # Latin Extended-A
        (0x0180, 0x024F),  # Latin Extended-B
        (0x0300, 0x036F),  # Combining Diacritical Marks
        (0x0300, 0x0323),  # (kept explicit: the two Vietnamese marks below)
        (0x1E00, 0x1EFF),  # Latin Extended Additional - Vietnamese lives here
        (0x2000, 0x206F),  # General Punctuation - quotes, dashes, ellipsis
        (0x20A0, 0x20BF),  # Currency Symbols - includes the dong sign
        (0x2190, 0x21FF),  # Arrows
        (0x2200, 0x22FF),  # Mathematical Operators
        (0x2500, 0x257F),  # Box Drawing - code blocks and tree output
        (0x25A0, 0x25FF),  # Geometric Shapes - bullets, task-list boxes
        (0x2600, 0x26FF),  # Miscellaneous Symbols
        (0xFB00, 0xFB06),  # Latin ligatures
        (0xFFFD, 0xFFFD),  # Replacement character - rule 9's visible fallback
    )
    return {chr(c) for lo, hi in ranges for c in range(lo, hi + 1)}


def _subset(source: str, destination: str, unicodes: set[str]) -> None:
    options = subset.Options()
    options.layout_features = ["*"]  # kerning, ligatures, positioning
    options.name_IDs = ["*"]  # keep the family and licence names
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables = ["FFTM"]

    # recalcTimestamp on the *font*, not just the subsetter option: TTFont
    # defaults to True and stamps head.modified on save, so two runs a second
    # apart produce files of identical length that differ in three bytes - the
    # timestamp and the checksums that follow from it. That is 5.4 MB of binary
    # churn in git for a rebuild that changed no glyph, in files no reviewer can
    # read a diff of. Measured, after setting only the subsetter option and
    # finding the output still differed.
    font = TTFont(source, recalcTimestamp=False)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=[ord(c) for c in unicodes])
    subsetter.subset(font)
    font.save(destination)
    font.close()


def _report(rows: list[tuple[str, int, int]]) -> None:
    print()
    print(f"{'file':<28} {'source':>12} {'subset':>12}   kept")
    total_before = total_after = 0
    for name, before, after in rows:
        total_before += before
        total_after += after
        print(f"{name:<28} {before:>12,} {after:>12,}   {100 * after / before:4.1f}%")
    print(f"{'TOTAL':<28} {total_before:>12,} {total_after:>12,}   "
          f"{100 * total_after / total_before:4.1f}%")


def main() -> None:
    print("sources:")
    cached = {name: _fetch(name, url, digest) for name, url, digest in SOURCES}

    with zipfile.ZipFile(cached["JetBrainsMono-2.304.zip"]) as archive:
        for member, name in JETBRAINS_MEMBERS.items():
            path = os.path.join(CACHE, name)
            with open(path, "wb") as handle:
                handle.write(archive.read(member))
            cached[name] = path

    os.makedirs(OUT, exist_ok=True)
    corpus = app_characters()
    latin = latin_characters() | corpus
    japanese = jis_x_0208() | corpus | latin_characters()

    print(f"\nrepertoire: latin {len(latin):,}  japanese {len(japanese):,} "
          f"(JIS X 0208 {len(jis_x_0208()):,} + {len(corpus):,} from the app)")

    plan: list[tuple[str, str, set[str]]] = [
        ("NotoSans-Regular.ttf", "NotoSans-Regular.ttf", latin),
        ("NotoSans-Bold.ttf", "NotoSans-Bold.ttf", latin),
        ("NotoSans-Italic.ttf", "NotoSans-Italic.ttf", latin),
        ("NotoSans-BoldItalic.ttf", "NotoSans-BoldItalic.ttf", latin),
        ("NotoSansJP-Regular.otf", "NotoSansJP-Regular.otf", japanese),
        ("NotoSansJP-Bold.otf", "NotoSansJP-Bold.otf", japanese),
        ("JetBrainsMono-Regular.ttf", "JetBrainsMono-Regular.ttf", latin),
        ("JetBrainsMono-Bold.ttf", "JetBrainsMono-Bold.ttf", latin),
    ]

    rows: list[tuple[str, int, int]] = []
    for source_name, out_name, unicodes in plan:
        source = cached[source_name]
        destination = os.path.join(OUT, out_name)
        _subset(source, destination, unicodes)
        rows.append(
            (out_name, os.path.getsize(source), os.path.getsize(destination))
        )

    _report(rows)


if __name__ == "__main__":
    sys.exit(main())
