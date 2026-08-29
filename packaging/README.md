# Packaging assets

What the M4 installers reference. Authored at M3 so that M4 is `iscc` and
`dpkg-deb` wiring against files that already exist, rather than authoring and
wiring at once — see `docs/15_SPIKES_ROADMAP.md`, "M3 build order", decision 2.

**Nothing here runs yet.** No workflow, no `CMakeLists` and no installer script
reads these files today. They are the *contents* of the file-association half
of doc 11; the mechanism is M4's. The icons below are the exception — they are
generated rather than authored, and the command that generates them is real.

| File | Consumed by | Registers |
|---|---|---|
| `windows/associations.iss` | Inno Setup script (M4) | ProgId `MarkLens.Document` for `.md` and `.mdx` |
| `linux/dev.poli0981.marklens.desktop` | `.deb` postinst, AppImage (M4) | `MimeType=text/markdown;text/mdx;` |
| `linux/marklens-mime.xml` | `.deb` postinst (M4) | `text/markdown` and `text/mdx` glob patterns |

## The icon, which used to be deliberately not here

It is here now. `linux/icons/hicolor/` holds the PNG set from 16 to 512 plus a
`scalable/` vector, all generated from `icon/marklens.svg` by
`tool/icons/render_icon.py`; the same run writes
`windows/runner/resources/app_icon.ico`, which had been byte-identical to the
Flutter template's default since M0.

Nothing in this directory is hand-edited. Regenerate with:

```bash
python tool/icons/render_icon.py
```

`icon/README.md` carries the provenance and the two defects the rebuild fixed
(an opaque black background at every size, and a shape filling 61% of its
canvas). The Windows `.ico` matters more than its one row suggests:
`windows/associations.iss` sets `DefaultIcon = {app}\marklens.exe,0`, so the
icon Explorer shows for every associated `.md` file is the exe's own — which is
why doc 11 called this an installer-forced decision rather than polish.

## The runtime half already works

Registering an association only tells the OS which program to launch with a
path as its argument. What happens then — a second launch handing its arguments
to the running window over loopback and exiting 0, rather than opening a rival
window — is `core/single_instance.dart`, shipped at M1 and verified against the
real binary on 2026-08-26 (`docs/15_SPIKES_ROADMAP.md`). So a double-click on a
`.md` file will land in the window that is already open, which is the whole
point of associating in the first place.
