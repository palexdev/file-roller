# Based on the Arch Linux PKGBUILD by:
#   Jan Alexander Steffens (heftig) <heftig@archlinux.org>
#   Fabian Bornschein <fabiscafe@archlinux.org>
#
# Patched to restore drag-and-drop extraction, removed during the GTK4 port.
# Deliberately named differently from `file-roller` so that `pacman -Syu` can
# never silently replace it with the stock package.

pkgname=file-roller-dnd
_pkgname=file-roller

# Set to 0 to build without the deferred-selection fix, i.e. with stock
# GtkTreeView behaviour where pressing on one of several selected rows
# collapses the selection before the drag starts.
_keep_selection=1
pkgver=44.7
pkgrel=1
pkgdesc="Create and modify archives (with drag-and-drop extraction restored)"
url="https://wiki.gnome.org/Apps/FileRoller"
arch=(x86_64)
license=(GPL-2.0-or-later)
provides=("file-roller=$pkgver")
conflicts=(file-roller)
depends=(
  dconf
  glib2
  glibc
  gtk4
  hicolor-icon-theme
  json-glib
  libadwaita
  libarchive
  libgcc
  libnautilus-extension
  pango
)
makedepends=(
  7zip
  arj
  binutils
  bzip3
  cdrtools
  cpio
  dpkg
  git
  glib2-devel
  lhasa
  lrzip
  meson
  python
  rpmextract
  squashfs-tools
  unace
  unrar
  unzip
  yelp-tools
  zip
)
optdepends=(
  '7zip: 7z archive support'
  'arj: arj archive support'
  'binutils: ar archive support'
  'bzip3: bzip3 compression support'
  'cdrtools: ISO image support'
  'cpio: cpio archive support'
  'dpkg: deb archive support'
  'lhasa: LHA/LZA archive support'
  'lrzip: lrzip compression support'
  'rpmextract: rpm archive support'
  'squashfs-tools: squashfs image support'
  'unace: ACE archive support'
  'unrar: better RAR archive support'
  'unzip: better ZIP archive support'
  'zip: better ZIP archive support'
)
groups=(gnome-extra)
source=("git+https://gitlab.gnome.org/GNOME/file-roller.git#tag=$pkgver"
        'file-roller-restore-dnd-extraction.patch'
        'file-roller-dnd-keep-selection.patch')
b2sums=('6f3a05d08c3f0f96e54b04e725e7cb90518e25614463017fdd53e816299ecb832aaa51de606975b650af30bd4a7021fd5dd111895de5a0634b733a8a60a8219a'
        '9f36607cfc7412a63a9070dd047af53551d8f841419ae8a698e7f3deeb9405d4bb89f7f45be3e02d2ec2cb5389285a9f9c622e4fa4ef1f53dbb5404f30131077'
        '75eb387407092f01591cafa87c71f40def134ec3bb16e47e0c9ec5460aa6cd5e77b162331c3b421e665aaf03f9f8f24bff363dcfbf8f98add47d99a21d335cc5')

prepare() {
  cd $_pkgname
  # --no-backup-if-mismatch: fail loudly rather than leaving .orig files around.
  # If this stops applying after a version bump, rebase the patch (see README).
  patch -Np1 --no-backup-if-mismatch -i "$srcdir/file-roller-restore-dnd-extraction.patch"

  # Applies on top of the above; touches only src/fr-window-dnd.c.
  if (( _keep_selection )); then
    patch -Np1 --no-backup-if-mismatch -i "$srcdir/file-roller-dnd-keep-selection.patch"
  fi
}

build() {
  arch-meson $_pkgname build
  meson compile -C build
}

check() {
  meson test -C build --print-errorlogs
}

package() {
  meson install -C build --destdir "$pkgdir"
}

# vim:set sw=2 sts=-1 et:
