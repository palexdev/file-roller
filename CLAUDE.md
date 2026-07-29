# file-roller-dnd

Custom Arch package: file-roller with drag-and-drop extraction restored,
broken since the GTK4 port. `README.md` has the full technical rationale —
read it before changing anything here.

## Build

    makepkg -Csi

**Always `-C`.** A dirty `src/` from a previous run makes `prepare()` apply the
patches to an already-patched checkout and fail.

Never run builds without asking first.

## Structure

- `file-roller-restore-dnd-extraction.patch` — the feature. Adds
  `src/fr-window-dnd.{c,h}` (new files) plus 3 tiny hunks in `fr-window.c`
  and 2 in `meson.build`. All additions, no deletions.
- `file-roller-dnd-keep-selection.patch` — optional, `_keep_selection` in the
  PKGBUILD. Touches only `src/fr-window-dnd.c`.

The patch shape is deliberate: nearly all code lives in a new file so version
bumps don't conflict. **Keep it that way** — if you need more logic, put it in
`fr-window-dnd.c`, not in `fr-window.c`.

## Updating to a new file-roller release

Bump `pkgver` (the source is a git tag) and rebuild. If `prepare()` fails, the
patch no longer applies — rebase it, never force it:

    git clone https://gitlab.gnome.org/GNOME/file-roller.git
    cd file-roller && git checkout -b dnd <old-tag>
    git am ../file-roller-restore-dnd-extraction.patch
    git rebase <new-tag>
    git format-patch -1 --stdout --no-signature > ../file-roller-restore-dnd-extraction.patch

Use `git rebase` so conflicts surface, rather than `patch --fuzz` silently
placing hunks in the wrong function.

## Why it is named `file-roller-dnd`

So `pacman -Syu` can never silently revert the patch. `provides`/`conflicts`
swap it for the stock package. Do not rename it back to `file-roller`.

## Known limitation

Hands over filesystem paths, so it will not work across sandboxes (Flatpak
file-roller → host Nautilus). The sandbox-safe design is streaming a tar
through the DnD pipe, which needs both applications patched.

## Open threads

- Publishing to GitHub (plain repo vs. AUR submission). Before publishing:
  replace the `SKIP` b2sums, add `.gitignore` for `src/`, `pkg/`,
  `file-roller/`, `*.pkg.tar.zst`.
- Sending patch 1 upstream to file-roller.
