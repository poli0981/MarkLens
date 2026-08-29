# The MarkLens icon

`marklens.svg` is the master. Everything else — the Linux hicolor set, the
Windows `.ico` — is generated from it and should never be edited by hand.

```bash
python tool/icons/render_icon.py
```

That writes all twelve artefacts and prints what it wrote. It needs Pillow on
the machine running it; Pillow is **not** a MarkLens dependency and never
reaches `pubspec.yaml`.

## Where the outputs go

| Output | Consumed by |
|---|---|
| `packaging/linux/icons/hicolor/<n>x<n>/apps/marklens.png` | the `.deb` and the AppImage, via `Icon=marklens` in the desktop entry |
| `packaging/linux/icons/hicolor/scalable/apps/marklens.svg` | the same, for desktops that prefer vector |
| `windows/runner/resources/app_icon.ico` | `Runner.rc`, and therefore the exe — **and therefore the `.md` file type**, because `associations.iss` sets `DefaultIcon = {app}\marklens.exe,0` |

That last row is why this could not stay open: registering a file association
also registers what that file type looks like in Explorer, so the icon is the
first thing anyone sees of this program (doc 11).

## Provenance

Original artwork by the maintainer, delivered as a raster export
(`icon-512.ico` plus a `layers/` set at nine sizes). The shape here is a rebuild
of it — the numbers in `tool/icons/render_icon.py` were measured off that export
rather than chosen: a near-square with a horizontal gradient from `#FFDD59` to
`#FF924D` and a corner radius of 3.3% of its width.

Two things changed in the rebuild, and both were defects rather than taste:

- **The export was flattened onto opaque black at every size.** Corner pixel
  `(0, 0, 0, 255)`, zero transparent pixels, and `icon-512.png` had no alpha
  channel at all. On Explorer's white background and in a GNOME dock that
  renders as a black tile with an orange rectangle inside it.
- **The shape occupied 61% of its canvas**, which reads small beside icons that
  fill theirs. It now fills 90%, with the margin rounded to a whole target pixel
  so the edge lands on the pixel grid at every size — without that, a 16px icon
  has a 0.8px margin, the downscale smears it, and the corners come out at
  alpha 11 instead of 0.

The icon carries no mark or letterform. That is the artwork as delivered, not an
omission of this pipeline; adding one is a design decision, and the place to
make it is `tool/icons/render_icon.py`.

## Why the geometry lives in a script rather than in the SVG

The conventional arrangement is a hand-drawn SVG plus a rasteriser, and it needs
a real SVG renderer. There is none on the dev machine — no Inkscape, no
librsvg, no cairosvg, no ImageMagick — so a hand-edited SVG could not be turned
into the PNG set reproducibly, which is the whole point of having a master.

Parameterising instead means the SVG and every PNG are outputs of the same
numbers, so they cannot drift. The cost is that the SVG is generated: **edit the
script, not the SVG.** If a designer later supplies genuine vector artwork, this
pipeline is the wrong shape and should be replaced with `rsvg-convert` in a
container — the arrangement `tool/goldens/` already uses for "the render has to
be reproducible on a machine that is not this one".

## Checked, not assumed

`test/repo/icon_assets_test.dart` asserts every hicolor size named here exists,
that each PNG's dimensions match the directory it sits in, that the corners are
actually transparent, and that `app_icon.ico` is no longer byte-identical to the
Flutter template's default — which it was, unnoticed, from M0 to M4.
