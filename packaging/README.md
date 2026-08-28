# Packaging assets

What the M4 installers reference. Authored at M3 so that M4 is `iscc` and
`dpkg-deb` wiring against files that already exist, rather than authoring and
wiring at once — see `docs/15_SPIKES_ROADMAP.md`, "M3 build order", decision 2.

**Nothing here runs yet.** No workflow, no `CMakeLists` and no installer script
reads these files today. They are the *contents* of the file-association half
of doc 11; the mechanism is M4's.

| File | Consumed by | Registers |
|---|---|---|
| `windows/associations.iss` | Inno Setup script (M4) | ProgId `MarkLens.Document` for `.md` and `.mdx` |
| `linux/marklens.desktop` | `.deb` postinst, AppImage (M4) | `MimeType=text/markdown;text/mdx;` |
| `linux/marklens-mime.xml` | `.deb` postinst (M4) | `text/markdown` and `text/mdx` glob patterns |

## What is deliberately not here: the icon

`windows/runner/resources/app_icon.ico` is **still the Flutter template's
icon**, and no Linux icon set exists. Both files below name `marklens` as the
icon and neither ships one, because shipping Google's Flutter logo as
MarkLens's brand would be worse than shipping nothing.

This is recorded the same way the bundled fonts are (doc 01, doc 15): an open
decision, not an oversight. It has to close before M4 packaging, because an
installer that registers a file type also registers what that file type *looks
like* in Explorer and in a file manager — and that is the first thing anyone
sees of this program.

## The runtime half already works

Registering an association only tells the OS which program to launch with a
path as its argument. What happens then — a second launch handing its arguments
to the running window over loopback and exiting 0, rather than opening a rival
window — is `core/single_instance.dart`, shipped at M1 and verified against the
real binary on 2026-08-26 (`docs/15_SPIKES_ROADMAP.md`). So a double-click on a
`.md` file will land in the window that is already open, which is the whole
point of associating in the first place.
