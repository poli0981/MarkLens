#!/usr/bin/env bash
# Builds marklens_<version>_amd64.deb from an existing Linux release bundle.
#
# Run inside the tool/linux container, which is where the release build happens
# (doc 11: Linux artefacts are never built outside CI, and the container is what
# makes "the same build" mean something on a Windows dev machine):
#
#     tool/linux/README.md
#
# It does not run flutter itself. The bundle is built once and packaged twice -
# once here and once by build-appimage.sh - so a .deb and an AppImage from the
# same release are the same binary rather than two builds that happen to agree.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bundle="$repo_root/build/linux/x64/release/bundle"
out_dir="$repo_root/build/installer"
staging="$repo_root/build/deb"

# pubspec.yaml is the single source of truth (doc 11). The `+build` suffix is
# pub metadata and is *illegal* in a Debian version, so it is stripped here the
# same way build.ps1 strips it for Inno - same regex, same reason.
version="$(sed -n 's/^version:[[:space:]]*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' \
  "$repo_root/pubspec.yaml")"
if [ -z "$version" ]; then
  echo "pubspec.yaml has no 'version: x.y.z' line" >&2
  exit 1
fi

# Overridable, and defaulted to a GitHub noreply address rather than to the
# maintainer's real one: contact.txt exists and must never reach the remote
# (see .gitignore). Debian requires the field to be well formed, not to be
# monitored.
maintainer="${MARKLENS_MAINTAINER:-poli0981 <poli0981@users.noreply.github.com>}"

if [ ! -x "$bundle/marklens" ]; then
  echo "No Linux bundle at $bundle - run flutter build linux --release" >&2
  exit 1
fi

rm -rf "$staging"
mkdir -p "$out_dir" \
  "$staging/DEBIAN" \
  "$staging/usr/bin" \
  "$staging/usr/lib/marklens" \
  "$staging/usr/share/applications" \
  "$staging/usr/share/mime/packages" \
  "$staging/usr/share/doc/marklens"

# ── The bundle ───────────────────────────────────────────────────────────────
# It goes to /usr/lib/marklens rather than straight into /usr/bin, because
# linux/CMakeLists.txt sets CMAKE_INSTALL_RPATH to $ORIGIN/lib: the executable
# has to sit beside its own lib/ directory or it will not start. /usr/bin gets a
# symlink, and glibc resolves $ORIGIN against the real path rather than the
# link, which is what makes that work - verified rather than assumed, see
# tool/linux/README.md.
cp -a "$bundle/." "$staging/usr/lib/marklens/"
ln -s ../lib/marklens/marklens "$staging/usr/bin/marklens"

# ── Desktop integration ──────────────────────────────────────────────────────
# The desktop entry keeps its application-id filename: that is what makes the
# desktop-file-id match StartupWMClass and the GTK app id (doc 11).
install -m 644 "$repo_root/packaging/linux/dev.poli0981.marklens.desktop" \
  "$staging/usr/share/applications/dev.poli0981.marklens.desktop"
install -m 644 "$repo_root/packaging/linux/marklens-mime.xml" \
  "$staging/usr/share/mime/packages/marklens.xml"
install -D -m 644 \
  "$repo_root/packaging/linux/dev.poli0981.marklens.metainfo.xml" \
  "$staging/usr/share/metainfo/dev.poli0981.marklens.metainfo.xml"

icons="$repo_root/packaging/linux/icons/hicolor"
for source in "$icons"/*/apps/marklens.*; do
  size_dir="$(basename "$(dirname "$(dirname "$source")")")"
  install -D -m 644 "$source" \
    "$staging/usr/share/icons/hicolor/$size_dir/apps/$(basename "$source")"
done

install -m 644 "$repo_root/LICENSE" \
  "$staging/usr/share/doc/marklens/copyright"

install -m 755 "$repo_root/packaging/linux/deb/DEBIAN/postinst" \
  "$repo_root/packaging/linux/deb/DEBIAN/prerm" \
  "$repo_root/packaging/linux/deb/DEBIAN/postrm" \
  "$staging/DEBIAN/"

# ── control ──────────────────────────────────────────────────────────────────
# Depends is derived, not guessed. dpkg-shlibdeps reads the actual NEEDED
# entries of the executable and every bundled .so and maps them back to the
# packages that provide them, so the list is a fact about this build rather than
# a list somebody remembered to update.
#
# Two things it insists on, both learned the slow way. It reads `debian/control`
# from the working directory even with -O, so a throwaway one is written and
# removed before the package is built - a debian/ directory inside the .deb
# would be its own bug. And -l takes its path attached: `-l lib` is read as
# another binary to analyse and fails with "Is a directory".
#
# stderr is deliberately not redirected. It carries the real errors as well as
# useful "could avoid a useless dependency" notes, and an earlier version of
# this script sent it to /dev/null, which turned a hard failure into an empty
# variable and a confusing exit 2.
mkdir -p "$staging/debian"
printf 'Source: marklens\n\nPackage: marklens\nArchitecture: amd64\n' \
  > "$staging/debian/control"
depends="$(
  cd "$staging" && dpkg-shlibdeps \
    --ignore-missing-info \
    -l"$staging/usr/lib/marklens/lib" \
    -O -e usr/lib/marklens/marklens usr/lib/marklens/lib/*.so \
    | sed -n 's/^shlibs:Depends=//p'
)"
rm -rf "$staging/debian"

if [ -z "$depends" ]; then
  echo "dpkg-shlibdeps produced no dependencies - refusing to ship a package" >&2
  echo "that claims to need nothing." >&2
  exit 1
fi

installed_size="$(du -ks "$staging" | cut -f1)"

sed -e "s|@VERSION@|$version|" \
    -e "s|@DEPENDS@|$depends|" \
    -e "s|@INSTALLED_SIZE@|$installed_size|" \
    -e "s|@MAINTAINER@|$maintainer|" \
    "$repo_root/packaging/linux/deb/DEBIAN/control.in" \
  > "$staging/DEBIAN/control"

# ── Build ────────────────────────────────────────────────────────────────────
# fakeroot so the archive records root:root ownership without needing root, and
# --root-owner-group as a belt-and-braces for the same thing.
package="$out_dir/marklens_${version}_amd64.deb"
rm -f "$package"
fakeroot dpkg-deb --root-owner-group --build "$staging" "$package" >/dev/null

echo "$package"
dpkg-deb --info "$package" | sed -n '1,12p'
