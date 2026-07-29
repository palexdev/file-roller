# Disclaimer

Code was made by Claude, I don't care, it works, deal with it  
Still less lazy than GNOME developers 🤷🏻

# file-roller

file-roller 44.7 with drag-and-drop extraction restored.

## What was broken

The drag *source* was commented out during file-roller's GTK4 port and never
reimplemented — see `src/fr-window.c:4830-4843` in stock 44.7. The old
implementation used XdndDirectSave (XDS), an X11 protocol where the drop
target sends a directory path back to the drag source. That is inverted
relative to Wayland's data-transfer model (source writes, target reads), and
under Flatpak a path is meaningless across sandbox boundaries. So it was
dropped rather than ported.

Nautilus is not at fault; its drop side works fine. `nautilus#2580` was closed
for that reason.

## How this patch works

Everything except the source-widget wiring survived the port: the private
fields (`drag_destination_folder`, `drag_base_dir`, `drag_file_list`,
`dnd_extract_is_running`) and `fr_window_dnd_extraction_finished()` are still
there, and the latter is still called from all six extraction completion
paths.

The patch adds a `GdkContentProvider` subclass that advertises
`text/uri-list`. GTK4 content providers write **asynchronously**, so when the
drop target reads the data we can extract the selection into a temporary
directory, take as long as we need, and only then write the resulting URIs.
This is exactly what the synchronous GTK3 `drag_data_get` could not do, and it
is why the async approach sidesteps the objection that killed the original
port. No XDS, no path travelling backwards, no new protocol — the file manager
receives an ordinary list of local files.

Temporary files live in `$XDG_CACHE_HOME/file-roller/dnd/<pid>-<n>/`. They are
not deleted when the drag ends, because the file manager copies them *after*
reading the uri-list. Directories belonging to dead PIDs are swept on first
use, so nothing accumulates.

**Known limitation:** this hands over filesystem paths, so it will not work if
file-roller and the file manager are in different sandboxes (e.g. a Flatpak
file-roller dropping into a host Nautilus). Both being host packages, as here,
is fine. The sandbox-safe fix is Benjamin Otte's proposal — stream a tar
through the DnD pipe — which needs both applications patched and a format
agreed upstream.

## Patch 2: keeping the selection intact (optional)

`file-roller-dnd-keep-selection.patch`, toggled by `_keep_selection` in the
PKGBUILD. Touches only `src/fr-window-dnd.c`, so it can be dropped without
affecting the extraction support.

Without it, selecting several entries and then pressing on one of them
collapses the selection to that single row before the drag begins.
`GtkTreeView` does `CLEAR_AND_SELECT` on button *press*
(`gtk/deprecated/gtktreeview.c:2980` in GTK 4.22), long before the drag
threshold is reached. GTK3 deferred that to button release whenever the tree
view was a drag source; the GTK4 port removed the deferral entirely — there is
no `source_set` check left in the press handler.

The fix restores the deferral from outside GTK. When a press lands on an
already-selected row of a multi-row selection, a `GtkTreeSelectionFunc`
returning `FALSE` is installed. `gtk_tree_selection_real_select_node()`
consults that function for *every* row whose state would change — including
the `unselect_all_helper` pass — so the whole `CLEAR_AND_SELECT` becomes a
no-op and the selection survives. On button release without a drag, the
suppressed selection change is applied, so a plain click still behaves
normally.

Ctrl/Shift presses are left alone, and the gesture is only installed on the
file list, not the sidebar.

## Patch shape (this is deliberate)

    src/fr-window-dnd.c | 513 ++++  (new file)
    src/fr-window-dnd.h |  50 ++++  (new file)
    src/fr-window.c     |   6 ++    (3 hunks: 1 include, 2 setup calls, 1 notify)
    src/meson.build     |   2 ++

All additions, zero deletions, and nearly all the code lives in a new file.
New files never conflict, so this should survive 44.8 / 45.x untouched.

## Installing

Both paths build under the package name **`file-roller-dnd`**, declaring
`Provides`/`Conflicts` on `file-roller`. Nothing in either distribution's
repositories carries that name, so a routine system upgrade can never silently
replace the patched build with the stock one — which is exactly what happens if
you keep the original name and only bump the release number.

### Arch / CachyOS

    makepkg -Csi

Always `-C`. A dirty `src/` from a previous run makes `prepare()` apply the
patches to an already-patched checkout and fail.

### Debian / Ubuntu

    ./build-deb.sh --deps      # shows how to install build dependencies
    ./build-deb.sh
    sudo apt install build-deb/file-roller-dnd_*.deb

The script builds whatever upstream version your distribution ships
(`apt-cache policy file-roller`), so the resulting package's dependencies line
up with the rest of your system; override with `FR_VERSION=44.7 ./build-deb.sh`.
Runtime dependencies are copied from the stock `file-roller` package rather
than hardcoded, because library package names drift between releases
(`libarchive13` vs `libarchive13t64`, and so on).

Set `KEEP_SELECTION=0` to build without the optional second patch.

### Update notifications (Arch only)

Because pacman cannot upgrade `file-roller-dnd`, `contrib/` has a hook that
tells you when upstream file-roller has moved on:

    sudo install -m755 contrib/file-roller-dnd-check.sh /usr/local/bin/file-roller-dnd-check
    sudo install -m644 contrib/file-roller-dnd-check.hook /etc/pacman.d/hooks/

## When a new file-roller is released

`pacman -Syu` will **not** touch this package — that is the point. To update:

1. Bump `pkgver` in the PKGBUILD (the source is a git tag, so that is enough).
2. `makepkg -si`.

If `prepare()` fails, the patch no longer applies. Rebase it properly rather
than forcing it:

    git clone https://gitlab.gnome.org/GNOME/file-roller.git
    cd file-roller
    git checkout -b dnd 44.7
    git am ../file-roller-restore-dnd-extraction.patch
    git rebase <new-tag>          # real 3-way merge, with conflict markers
    git format-patch -1 --stdout --no-signature \
        > ../file-roller-restore-dnd-extraction.patch

Use `git rebase`, never `patch --fuzz`, so conflicts are reported instead of
hunks being silently placed in the wrong function.

## Things to check on first run

The drag source is attached to a `GtkTreeView` that already has its own click
gesture (`list_view_button_pressed_cb`, registered in the *capture* phase).
The `GtkDragSource` here runs in the *bubble* phase so selection updates
happen first. If drags do not start at all, that interaction is the first
thing to look at — try `GTK_PHASE_CAPTURE`, or lower the click gesture's
priority.
