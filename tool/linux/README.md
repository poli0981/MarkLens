# Building the Linux artefacts

`docs/11_PACKAGING_UPDATE.md` and `docs/14_CI_CD.md`. The dev machine is
Windows, and Linux release artefacts are never built outside a controlled
environment — this is that environment, and CI runs the same image.

```bash
docker build -t marklens-linux tool/linux
```

Then, from the repo root, one build and two packagings:

```bash
docker run --rm -v "$PWD:/src:ro" -v "$PWD/build:/out" marklens-linux bash -lc 'mkdir -p ~/work && cd /src && tar cf - --exclude=./.git --exclude=./build --exclude=./.dart_tool . | (cd ~/work && tar xf -) && cd ~/work && flutter pub get >/dev/null && flutter build linux --release && packaging/linux/build-deb.sh && packaging/linux/build-appimage.sh && cp -r build/installer /out/'
```

The repo is copied in rather than mounted read-write, the same arrangement
`tool/goldens/` uses and for the same reason: `flutter pub get` and `cmake`
would otherwise leave a Linux `.dart_tool` and a Linux `build/` in the Windows
tree, and the next Windows build would trip over them.

**The bundle is built once and packaged twice.** A `.deb` and an AppImage from
one release are then the same binary rather than two builds that happen to
agree.

## Why ubuntu:22.04, and why a container

The glibc a binary is linked against is the glibc of the machine that built it,
and it is a floor rather than a target: something built on 22.04 runs on 24.04,
and the reverse fails at load time with a message about `GLIBC_2.3x`. Ubuntu
22.04 is the charter's platform floor, so that is the base.

Doc 14 originally said to use the `ubuntu-22.04` *runner*. Those images begin
deprecation on 2026-09-17 and are unsupported from 2027-04-17, which would give
the release pipeline a seven-month life. Pinning the image instead makes the
floor a property of something this repo controls.

## The symlink, and why `ldd` lies about it

`linux/CMakeLists.txt` sets `CMAKE_INSTALL_RPATH` to `$ORIGIN/lib`, so the
executable has to sit beside its own `lib/`. The `.deb` installs the bundle to
`/usr/lib/marklens/` and makes `/usr/bin/marklens` a symlink into it.

**Checked, not assumed.** Installing the package and running
`xvfb-run /usr/bin/marklens --version` prints `MarkLens 0.1.0` and exits 0, and
`LD_DEBUG=libs` shows the loader initialising
`/usr/lib/marklens/lib/libflutter_linux_gtk.so`. glibc expands `$ORIGIN` from
the *resolved* path of the executable, not from the symlink used to invoke it.

But `ldd` does not:

```
$ ldd /usr/bin/marklens | grep 'not found'
        libdesktop_drop_plugin.so => not found
        libscreen_retriever_linux_plugin.so => not found
        liburl_launcher_linux_plugin.so => not found
        libwindow_manager_plugin.so => not found
        libflutter_linux_gtk.so => not found

$ ldd /usr/lib/marklens/marklens | grep -c 'not found'
0
```

`ldd` resolves `$ORIGIN` against the path it was *given*, so through the symlink
it looks in `/usr/bin/lib/`. Anybody diagnosing this package the obvious way
will see five missing libraries and conclude it is broken. It is not — check
the real path, or run it.

## The execute bit, which Windows cannot give you

`build-deb.sh`, `build-appimage.sh` and `AppRun` are `100755` in the index, and
they have to be set with git rather than with the filesystem:

```bash
git update-index --chmod=+x packaging/linux/build-deb.sh
```

The dev machine has `core.fileMode=false`, so `chmod +x` succeeds and records
nothing. The first release rehearsal failed on exactly this — a fresh Linux
checkout produced a `100644` script and the job exited 126, "Permission
denied" — and no local run could have caught it, because every local run said
`bash packaging/linux/build-deb.sh`, naming the interpreter and making the mode
irrelevant. The only caller that did not name one was the workflow, and the
workflow was the only caller that had never run.

`test/repo/script_mode_test.dart` reads the mode back out of the index, which
is the only place it is visible from here.

## Running the artefacts here

The container has `xvfb`, so both artefacts can be started rather than merely
weighed. A GTK application needs a display even to answer `--version`: the
window is created before the Dart entrypoint sees `argv`, so without one it
exits 1 with `cannot open display`. That is a property of the Flutter Linux
embedder rather than of MarkLens's argument handling, and it is worth knowing
before reading too much into a headless failure.

The AppImage also needs `APPIMAGE_EXTRACT_AND_RUN=1` to run in a container or on
a CI runner, because mounting itself needs FUSE and neither provides it.

```bash
APPIMAGE_EXTRACT_AND_RUN=1 xvfb-run -a build/installer/MarkLens-*.AppImage --version
xvfb-run -a /usr/bin/marklens --version   # after dpkg -i
```

What none of this covers is the clean-VM run (doc 15, S3): file dialogs, the
icon in a real file manager, double-clicking a `.md`, and whether the AppImage
starts on a machine that is not this image.
