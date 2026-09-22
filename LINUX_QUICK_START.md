# ACORN HUNTER — Linux one-click launcher

The project includes a Linux launcher that keeps the local copy synchronized with the GitHub `main` branch and then opens the project in Godot.

## One-time setup

From a cloned/downloaded copy of this repository:

```bash
bash tools/linux/install_linux_shortcut.sh
```

The installer creates:

- `~/Desktop/ACORN HUNTER — Update & Open.desktop`
- `~/.local/share/applications/acorn-hunter.desktop`
- `~/.local/bin/acorn-hunter`

## After that

Double-click **ACORN HUNTER — Update & Open**.

The launcher will:

1. Download `masterofmagic234/Arkon` if `~/ACORN_HUNTER/Arkon` does not exist.
2. Otherwise fetch `origin/main`.
3. Fast-forward the local checkout when a newer commit exists.
4. Refuse to update if there are uncommitted local changes, so your work is not silently overwritten.
5. Open the updated project in Godot 4.x.

The desktop shortcut also has a **Update & Play Game** action in its context menu. That starts the project's configured main scene instead of opening the editor.

## Requirements

- Git
- Godot 4.x available as `godot` or `godot4`

Godot is launched with `--path ~/ACORN_HUNTER/Arkon`; the editor uses `--editor`. The project itself defines its main scene, so the launcher does not hard-code a particular level.

## Local work protection

The updater uses a fast-forward-only Git update. If the local checkout contains uncommitted changes, it stops instead of overwriting them.

If you intentionally want to discard local changes and return to GitHub `main`, do that manually in the repository before using the shortcut again.


## Local changes policy

The Linux updater intentionally treats GitHub `main` as the source of truth. Before opening the project it resets tracked local changes to `origin/main` and removes untracked files. Do not keep development changes only on this machine; commit them to GitHub unless you explicitly want a local-only change.
