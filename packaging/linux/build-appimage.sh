#!/usr/bin/env bash
# Builds MarkLens-<version>-x86_64.AppImage from an existing Linux release
# bundle. Run inside the tool/linux container - see tool/linux/README.md.
#
# The bundle is built once and packaged twice, here and in build-deb.sh, so the
# AppImage and the .deb from one release are the same binary.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bundle="$repo_root/build/linux/x64/release/bundle"
out_dir="$repo_root/build/installer"
appdir="$repo_root/build/AppDir"
cache="$repo_root/build/appimagetool"

# appimagetool is fetched at build time, into the one workflow that will hold
# `contents: write`. So it is pinned by tag *and* verified by SHA-256 before it
# is executed - an unpinned `continuous` download run as a build step is a
# supply-chain hole in the worst possible place. The digest comes from the
# GitHub release API, which reports it for the asset.
APPIMAGETOOL_TAG="1.9.1"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_TAG}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"

# And the runtime, which is a *second* download and the one that is easy to
# miss: left to itself appimagetool fetches
# type2-runtime/releases/download/continuous/runtime-x86_64 and embeds it in the
# artefact - an unpinned binary from a moving tag, welded into the thing users
# download. Pinning appimagetool alone would have closed the smaller of the two
# holes while the comment claimed both. `20251108` is the dated release; the
# `continuous` one is a different file today than it was last week.
APPIMAGE_RUNTIME_TAG="20251108"
APPIMAGE_RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/${APPIMAGE_RUNTIME_TAG}/runtime-x86_64"
APPIMAGE_RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

version="$(sed -n 's/^version:[[:space:]]*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' \
  "$repo_root/pubspec.yaml")"
if [ -z "$version" ]; then
  echo "pubspec.yaml has no 'version: x.y.z' line" >&2
  exit 1
fi

if [ ! -x "$bundle/marklens" ]; then
  echo "No Linux bundle at $bundle - run flutter build linux --release" >&2
  exit 1
fi

# ── appimagetool ─────────────────────────────────────────────────────────────
mkdir -p "$cache" "$out_dir"

fetch_pinned() {
  # $1 destination, $2 url, $3 sha256, $4 what it is
  [ -f "$1" ] && return 0
  curl -fsSL -o "$1.part" "$2"
  local actual
  actual="$(sha256sum "$1.part" | cut -d' ' -f1)"
  if [ "$actual" != "$3" ]; then
    rm -f "$1.part"
    echo "$4: sha256 mismatch" >&2
    echo "  expected $3" >&2
    echo "  got      $actual" >&2
    echo "Do not just update the constant - find out which one moved." >&2
    exit 1
  fi
  mv "$1.part" "$1"
}

tool="$cache/appimagetool-${APPIMAGETOOL_TAG}-x86_64.AppImage"
runtime="$cache/runtime-${APPIMAGE_RUNTIME_TAG}-x86_64"
fetch_pinned "$tool" "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA256" appimagetool
fetch_pinned "$runtime" "$APPIMAGE_RUNTIME_URL" "$APPIMAGE_RUNTIME_SHA256" runtime
chmod +x "$tool"

# ── AppDir ───────────────────────────────────────────────────────────────────
# Same layout as the .deb installs, which is deliberate: one filesystem shape
# means the AppRun path and the /usr/bin symlink are the same relative walk, and
# a bug in one is a bug in both rather than a bug in whichever was tested less.
rm -rf "$appdir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/lib/marklens" \
  "$appdir/usr/share/applications" "$appdir/usr/share/metainfo"

cp -a "$bundle/." "$appdir/usr/lib/marklens/"
ln -s ../lib/marklens/marklens "$appdir/usr/bin/marklens"

install -m 755 "$repo_root/packaging/linux/AppRun" "$appdir/AppRun"

# appimagetool wants the desktop entry and an icon at the AppDir root, and the
# desktop file also has to be where a desktop-integration tool would look for
# it - hence both copies rather than a choice between them.
desktop="$repo_root/packaging/linux/dev.poli0981.marklens.desktop"
install -m 644 "$desktop" "$appdir/dev.poli0981.marklens.desktop"
install -m 644 "$desktop" \
  "$appdir/usr/share/applications/dev.poli0981.marklens.desktop"
install -m 644 "$repo_root/packaging/linux/dev.poli0981.marklens.metainfo.xml" \
  "$appdir/usr/share/metainfo/dev.poli0981.marklens.metainfo.xml"

icons="$repo_root/packaging/linux/icons/hicolor"
for source in "$icons"/*/apps/marklens.*; do
  size_dir="$(basename "$(dirname "$(dirname "$source")")")"
  install -D -m 644 "$source" \
    "$appdir/usr/share/icons/hicolor/$size_dir/apps/$(basename "$source")"
done
# Icon=marklens resolves against the AppDir root for the AppImage's own
# thumbnail, so the 256 goes there under the name the desktop entry asks for.
install -m 644 "$icons/256x256/apps/marklens.png" "$appdir/marklens.png"

# ── Build ────────────────────────────────────────────────────────────────────
# appimagetool is itself an AppImage and needs FUSE to mount itself, which no
# container and no GitHub runner provides. APPIMAGE_EXTRACT_AND_RUN makes it
# unpack to a temp directory instead.
package="$out_dir/MarkLens-${version}-x86_64.AppImage"
rm -f "$package"
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$tool" \
  --runtime-file "$runtime" "$appdir" "$package" >/dev/null
chmod +x "$package"

echo "$package"
ls -l "$package" | awk '{print $5, $9}'
