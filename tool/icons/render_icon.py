#!/usr/bin/env python3
"""Render every MarkLens icon artefact from one set of numbers.

Run from the repo root:

    python tool/icons/render_icon.py

It writes, and is the only thing that should write:

    icon/marklens.svg                                       the master, also
    packaging/linux/icons/hicolor/scalable/apps/marklens.svg  copied to hicolor
    packaging/linux/icons/hicolor/<n>x<n>/apps/marklens.png
    windows/runner/resources/app_icon.ico

The geometry below *is* the master. That is a deliberate choice and worth
stating, because the obvious arrangement - a hand-drawn SVG plus a rasteriser -
needs a real SVG renderer, and there is none on the dev machine (no Inkscape, no
librsvg, no cairosvg; ImageMagick is absent too). Parameterising instead means
the SVG and the PNGs cannot drift, because they are two outputs of the same
seven numbers rather than one derived from the other by a tool nobody has.

If a designer ever supplies a genuine hand-drawn SVG, this script is the wrong
shape and should be replaced by `rsvg-convert` in a container, the way
`tool/goldens/` already handles "the render must be reproducible".

Dependencies: Pillow (dev machine only - it is not a MarkLens dependency and
never reaches `pubspec.yaml`). Everything else is the standard library.

The numbers come from measuring the maintainer's raster export rather than from
taste: a near-square with a horizontal warm gradient. What changed in the
rebuild is the two things that were wrong rather than stylistic - the export was
flattened onto opaque black at every size (corner pixel 0,0,0,255, zero
transparent pixels), and the shape occupied 61% of its canvas, which reads small
in a dock beside icons that fill theirs.
"""

from __future__ import annotations

import io
import os
import struct
from typing import Final

from PIL import Image, ImageDraw

# ── The master ────────────────────────────────────────────────────────────────
# Fractions of the canvas, so every size is the same picture.

MARGIN: Final[float] = 0.05  # each side; shape fills 90% of the canvas
RADIUS: Final[float] = 0.033  # of the shape's width, measured off the export
GRADIENT_LEFT: Final[tuple[int, int, int]] = (0xFF, 0xDD, 0x59)
GRADIENT_RIGHT: Final[tuple[int, int, int]] = (0xFF, 0x92, 0x4D)

# Supersampling factor for the raster path. 8x is well past the point where the
# downscale stops improving and is still instant at 512.
SUPERSAMPLE: Final[int] = 8

# hicolor sizes shipped, plus the ICO frames. Both lists are also asserted by
# test/repo/icon_assets_test.dart, so adding a size means adding it there.
PNG_SIZES: Final[tuple[int, ...]] = (16, 24, 32, 48, 64, 96, 128, 256, 512)
ICO_SIZES: Final[tuple[int, ...]] = (16, 24, 32, 48, 64, 96, 128, 256)

REPO_ROOT: Final[str] = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HICOLOR: Final[str] = os.path.join(REPO_ROOT, "packaging", "linux", "icons", "hicolor")


def _hex(rgb: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % rgb


def render_png(size: int) -> Image.Image:
    """The icon at `size`, RGBA, transparent outside the rounded square."""
    scale = SUPERSAMPLE
    big = size * scale
    # Round the margin to a whole *target* pixel before scaling up, so the
    # shape's edge lands on the pixel grid at every size. Without it a 16px
    # icon has a 0.8px margin, the downscale spreads it across the whole
    # border, and the corners come out at alpha 11 instead of 0 - a faint halo
    # on exactly the size where it is most visible.
    inset = max(1, round(MARGIN * size)) * scale
    shape_w = big - 2 * inset
    radius = round(RADIUS * shape_w)

    # The gradient is painted across the full width first, then masked by the
    # rounded rectangle. Painting it inside the mask instead would make the
    # colour at a given pixel depend on the mask's bounding box, which is the
    # same thing here but stops being so the moment the shape changes.
    gradient = Image.new("RGB", (big, 1))
    row = gradient.load()
    span = max(1, big - 1)
    for x in range(big):
        t = x / span
        row[x, 0] = tuple(
            round(a + (b - a) * t)
            for a, b in zip(GRADIENT_LEFT, GRADIENT_RIGHT)
        )
    gradient = gradient.resize((big, big), Image.NEAREST)

    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset, inset, big - inset - 1, big - inset - 1),
        radius=radius,
        fill=255,
    )

    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(gradient, (0, 0), mask)
    # BOX, not LANCZOS: the factor is an exact integer, so an area average is
    # both exact and free of the overshoot a windowed-sinc filter puts either
    # side of a hard edge - and this picture is nothing but one hard edge.
    return out.resize((size, size), Image.BOX)


def svg() -> str:
    """The same picture as vector, for hicolor's `scalable/`.

    The geometry is rounded exactly the way `render_png(512)` rounds it, so the
    vector and the largest raster are the same picture to the pixel rather than
    to 0.4 of one.
    """
    inset = max(1, round(MARGIN * 512))
    shape = 512 - 2 * inset
    radius = round(RADIUS * shape)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!--
  MarkLens application icon. Generated by tool/icons/render_icon.py, which holds
  the geometry; edit the script rather than this file, or the next run will
  overwrite the change. Original artwork by the MarkLens maintainer; this is a
  rebuild of it with a transparent background and a 90% canvas fill.
-->
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"
     viewBox="0 0 512 512" role="img" aria-label="MarkLens">
  <defs>
    <linearGradient id="marklens" x1="0" y1="0" x2="512" y2="0"
                    gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{_hex(GRADIENT_LEFT)}"/>
      <stop offset="1" stop-color="{_hex(GRADIENT_RIGHT)}"/>
    </linearGradient>
  </defs>
  <rect x="{inset:g}" y="{inset:g}" width="{shape:g}" height="{shape:g}"
        rx="{radius:g}" ry="{radius:g}" fill="url(#marklens)"/>
</svg>
"""


def write_ico(path: str, sizes: tuple[int, ...]) -> None:
    """An all-PNG, 32-bpp ICO.

    Written by hand rather than through Pillow's ICO writer, which stores small
    frames as BMP. The platform floor is Windows 10, which reads PNG frames at
    every size, and an all-PNG file is both smaller and what the maintainer's
    original export already was - so a diff of the two is a diff of the picture
    rather than of two container conventions.
    """
    frames: list[bytes] = []
    for size in sizes:
        buffer = io.BytesIO()
        render_png(size).save(buffer, format="PNG", optimize=True)
        frames.append(buffer.getvalue())

    header = struct.pack("<HHH", 0, 1, len(sizes))
    offset = len(header) + 16 * len(sizes)
    directory = b""
    for size, blob in zip(sizes, frames):
        # 0 means 256 in an ICO directory entry; nothing larger is expressible.
        byte = 0 if size >= 256 else size
        directory += struct.pack(
            "<BBBBHHII", byte, byte, 0, 0, 1, 32, len(blob), offset
        )
        offset += len(blob)

    with open(path, "wb") as handle:
        handle.write(header + directory + b"".join(frames))


def main() -> None:
    written: list[str] = []

    for size in PNG_SIZES:
        directory = os.path.join(HICOLOR, f"{size}x{size}", "apps")
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, "marklens.png")
        render_png(size).save(path, format="PNG", optimize=True)
        written.append(path)

    scalable = os.path.join(HICOLOR, "scalable", "apps")
    os.makedirs(scalable, exist_ok=True)
    for path in (
        os.path.join(REPO_ROOT, "icon", "marklens.svg"),
        os.path.join(scalable, "marklens.svg"),
    ):
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(svg())
        written.append(path)

    ico = os.path.join(REPO_ROOT, "windows", "runner", "resources", "app_icon.ico")
    write_ico(ico, ICO_SIZES)
    written.append(ico)

    for path in written:
        print(os.path.relpath(path, REPO_ROOT).replace(os.sep, "/"))


if __name__ == "__main__":
    main()
