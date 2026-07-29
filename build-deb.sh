#!/usr/bin/env bash
#
# Build a file-roller-dnd .deb on Debian/Ubuntu.
#
# Mirrors what the PKGBUILD does on Arch: builds patched file-roller under a
# *different package name* with Provides/Conflicts/Replaces on file-roller, so
# `apt upgrade` can never silently reinstall the unpatched version over it.
#
# Usage:
#   ./build-deb.sh              # build a .deb into ./build-deb/
#   ./build-deb.sh --deps       # show/install the build dependencies
#   FR_VERSION=44.7 ./build-deb.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="$HERE/build-deb"
UPSTREAM="https://gitlab.gnome.org/GNOME/file-roller.git"

PATCHES=(
    "file-roller-restore-dnd-extraction.patch"
)
# Set KEEP_SELECTION=0 to build without the deferred-selection fix.
if [[ ${KEEP_SELECTION:-1} == 1 ]]; then
    PATCHES+=("file-roller-dnd-keep-selection.patch")
fi

die() { printf '\e[31merror:\e[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\e[34m==>\e[0m %s\n' "$*"; }


# Build against the same upstream version Debian ships, so the dependencies
# resolved below actually match. Override with FR_VERSION.
detect_version() {
    local v
    v=$(apt-cache policy file-roller 2>/dev/null | awk '/Candidate:/ {print $2}')
    [[ -z $v || $v == "(none)" ]] && return 1
    # strip epoch and Debian revision: 1:44.7-1 -> 44.7
    v=${v#*:}
    v=${v%%-*}
    printf '%s' "$v"
}

install_deps() {
    info "Preferred: let apt work out file-roller's own build dependencies."
    echo "    sudo apt-get build-dep file-roller"
    echo "  (needs deb-src lines enabled in your apt sources)"
    echo
    info "Fallback, if build-dep is unavailable:"
    cat <<'EOF'
    sudo apt-get install build-essential meson ninja-build pkg-config git \
        libglib2.0-dev libgtk-4-dev libadwaita-1-dev libarchive-dev \
        libjson-glib-dev libnautilus-extension-dev itstool yelp-tools \
        desktop-file-utils gettext
EOF
}

[[ ${1:-} == "--deps" ]] && { install_deps; exit 0; }

command -v dpkg-deb >/dev/null || die "dpkg-deb not found; this script is for Debian/Ubuntu."
command -v meson   >/dev/null || { install_deps; die "meson not found."; }
command -v git     >/dev/null || die "git not found."

FR_VERSION="${FR_VERSION:-$(detect_version || echo 44.7)}"
ARCH=$(dpkg --print-architecture)
info "Building file-roller $FR_VERSION for $ARCH"

# Reuse the stock package's dependency list. Package names for the same
# libraries differ between Debian releases (libarchive13 vs libarchive13t64,
# and so on), so deriving them beats hardcoding.
DEPS=$(dpkg-query -f '${Depends}' -W file-roller 2>/dev/null || true)
if [[ -z $DEPS ]]; then
    DEPS=$(apt-cache show file-roller 2>/dev/null | awk -F': ' '/^Depends: / {print $2; exit}' || true)
fi
[[ -z $DEPS ]] && info "warning: could not determine runtime dependencies; the .deb will declare none."

mkdir -p "$WORKDIR"
SRC="$WORKDIR/file-roller"

if [[ -d $SRC/.git ]]; then
    info "Refreshing existing checkout"
    git -C "$SRC" fetch --tags --quiet origin
else
    info "Cloning upstream"
    git clone --quiet "$UPSTREAM" "$SRC"
fi

info "Checking out $FR_VERSION"
git -C "$SRC" checkout -f --quiet "$FR_VERSION" || die "no upstream tag '$FR_VERSION'"
git -C "$SRC" clean -fdxq

for p in "${PATCHES[@]}"; do
    info "Applying $p"
    patch -d "$SRC" -Np1 --no-backup-if-mismatch -i "$HERE/$p" \
        || die "$p did not apply to $FR_VERSION. See README.md for how to rebase it."
done

info "Configuring"
rm -rf "$WORKDIR/build"
meson setup "$WORKDIR/build" "$SRC" --prefix=/usr --buildtype=release

info "Compiling"
meson compile -C "$WORKDIR/build"

STAGING="$WORKDIR/staging"
rm -rf "$STAGING"
info "Staging install"
meson install -C "$WORKDIR/build" --destdir "$STAGING" >/dev/null

INSTALLED_SIZE=$(du -sk "$STAGING" | cut -f1)
mkdir -p "$STAGING/DEBIAN"
cat > "$STAGING/DEBIAN/control" <<EOF
Package: file-roller-dnd
Version: ${FR_VERSION}-1
Architecture: ${ARCH}
Maintainer: local build <root@localhost>
Installed-Size: ${INSTALLED_SIZE}
Depends: ${DEPS}
Provides: file-roller (= ${FR_VERSION})
Conflicts: file-roller
Replaces: file-roller
Section: utils
Priority: optional
Homepage: https://wiki.gnome.org/Apps/FileRoller
Description: Create and modify archives (drag-and-drop extraction restored)
 file-roller built with a patch restoring the ability to drag files out of an
 archive and drop them into a file manager, which has been missing since the
 GTK4 port.
 .
 Deliberately named differently from the stock file-roller package so that an
 apt upgrade cannot silently replace it with the unpatched version.
EOF

DEB="$WORKDIR/file-roller-dnd_${FR_VERSION}-1_${ARCH}.deb"
info "Packaging"
dpkg-deb --build --root-owner-group "$STAGING" "$DEB" >/dev/null

info "Built $DEB"
echo
echo "Install with:"
echo "    sudo apt install $DEB"
