#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/masterofmagic234/Arkon.git"
INSTALL_DIR="${HOME}/.local/bin"
LAUNCHER="${INSTALL_DIR}/acorn-hunter"
DESKTOP_DIR="${HOME}/Desktop"
APPLICATIONS_DIR="${HOME}/.local/share/applications"

mkdir -p "${INSTALL_DIR}" "${APPLICATIONS_DIR}"

# The installed launcher is intentionally self-contained, so it can update
# the repository before the repository itself is opened.
cat > "${LAUNCHER}" <<'LAUNCHER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/masterofmagic234/Arkon.git"
PROJECT_DIR="${HOME}/ACORN_HUNTER/Arkon"
BRANCH="main"
MODE="${1:-editor}"

say() { printf '\n[ACORN HUNTER] %s\n' "$*"; }
fail() {
    printf '\n[ACORN HUNTER] ERROR: %s\n' "$*" >&2
    printf '\nPress Enter to close...'
    read -r || true
    exit 1
}

command -v git >/dev/null 2>&1 || fail "Git is not installed."
if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot4)"
else
    fail "Godot 4.x was not found as 'godot' or 'godot4'."
fi

mkdir -p "${HOME}/ACORN_HUNTER"

if [[ ! -d "${PROJECT_DIR}/.git" ]]; then
    say "Downloading the latest ACORN HUNTER from GitHub..."
    rm -rf "${PROJECT_DIR}"
    git clone --branch "${BRANCH}" --single-branch "${REPO_URL}" "${PROJECT_DIR}" ||
        fail "GitHub download failed."
else
    say "Checking GitHub for a newer version..."
    git -C "${PROJECT_DIR}" fetch --prune origin "${BRANCH}" ||
        fail "Could not contact GitHub."

    LOCAL_SHA="$(git -C "${PROJECT_DIR}" rev-parse HEAD)"
    REMOTE_SHA="$(git -C "${PROJECT_DIR}" rev-parse "origin/${BRANCH}")"

    if [[ "${LOCAL_SHA}" != "${REMOTE_SHA}" ]] || [[ -n "$(git -C "${PROJECT_DIR}" status --porcelain)" ]]; then
        say "Synchronizing local project with origin/${BRANCH}..."
        say "GitHub main is the source of truth; local uncommitted changes will be discarded."
        git -C "${PROJECT_DIR}" reset --hard "origin/${BRANCH}" ||
            fail "Could not reset local repository to origin/${BRANCH}."
        git -C "${PROJECT_DIR}" clean -fd ||
            fail "Could not remove local untracked files."
    else
        say "Already up to date."
    fi
fi

[[ -f "${PROJECT_DIR}/project.godot" ]] || fail "project.godot was not found."

say "Godot: $("${GODOT_BIN}" --version 2>/dev/null || true)"
case "${MODE}" in
    game)   exec "${GODOT_BIN}" --path "${PROJECT_DIR}" ;;
    editor) exec "${GODOT_BIN}" --editor --path "${PROJECT_DIR}" ;;
    *) fail "Unknown mode '${MODE}'." ;;
esac
LAUNCHER_EOF

chmod +x "${LAUNCHER}"

cat > "${APPLICATIONS_DIR}/acorn-hunter.desktop" <<DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ACORN HUNTER — Update & Open
Comment=Update ACORN HUNTER from GitHub and open it in Godot
Exec=/bin/bash -lc "${LAUNCHER} editor"
Terminal=true
Categories=Game;Development;
StartupNotify=true
Actions=Play;

[Desktop Action Play]
Name=Update & Play Game
Exec=/bin/bash -lc "${LAUNCHER} game"
Terminal=true
DESKTOP_EOF

chmod +x "${APPLICATIONS_DIR}/acorn-hunter.desktop"

if [[ -d "${DESKTOP_DIR}" ]]; then
    DESKTOP_FILE="${DESKTOP_DIR}/ACORN HUNTER — Update & Open.desktop"
    cp "${APPLICATIONS_DIR}/acorn-hunter.desktop" "${DESKTOP_FILE}"
    chmod +x "${DESKTOP_FILE}"

    # GNOME/Nautilus and compatible desktops may require the file to be
    # explicitly marked as trusted before allowing a desktop file to launch.
    if command -v gio >/dev/null 2>&1; then
        gio set "${DESKTOP_FILE}" metadata::trusted true 2>/dev/null || true
    fi
fi

update-desktop-database "${APPLICATIONS_DIR}" >/dev/null 2>&1 || true

printf '\nACORN HUNTER launcher installed.\n'
printf 'Desktop shortcut: %s\n' "${DESKTOP_DIR}/ACORN HUNTER — Update & Open.desktop"
printf 'App menu entry:   %s\n' "${APPLICATIONS_DIR}/acorn-hunter.desktop"
printf '\nClick the shortcut: it downloads/updates main from GitHub and opens Godot.\n'
printf 'The shortcut context menu also contains “Update & Play Game”.\n'
