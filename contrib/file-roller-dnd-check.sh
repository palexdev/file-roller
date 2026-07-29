#!/bin/bash
# Warn when upstream file-roller has moved past the locally built
# file-roller-dnd, since pacman deliberately cannot upgrade it.
#
# Install to /usr/local/bin/file-roller-dnd-check (chmod +x) together with
# file-roller-dnd-check.hook in /etc/pacman.d/hooks/.

set -u

installed=$(pacman -Q file-roller-dnd 2>/dev/null | awk '{print $2}')
[[ -z $installed ]] && exit 0

# Best effort: pacman still holds the DB lock during PostTransaction hooks on
# some configurations. Failing to read the sync DB is not an error.
available=$(pacman -Si file-roller 2>/dev/null | awk -F': *' '/^Version/ {print $2; exit}')
[[ -z $available ]] && exit 0

# Compare upstream versions only, ignoring our own pkgrel.
if [[ $(vercmp "${available%%-*}" "${installed%%-*}") -gt 0 ]]; then
    cat <<EOF
==> file-roller-dnd is out of date.
    installed: $installed   upstream file-roller: $available
    Bump pkgver in your PKGBUILD and rebuild with: makepkg -Csi
EOF
fi

exit 0
