#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/masterofmagic234/Arkon.git"
PROJECT_DIR="${HOME}/ACORN_HUNTER/Arkon"
BRANCH="main"
MODE="${1:-editor}"

say() {
    printf '\n[ACORN HUNTER] %s\n' "$*"
}

fail() {
    printf '\n[ACORN HUNTER] ERROR: %s\n' "$*" >&2
    printf '\nPress Enter to close...'
    read -r || true
    exit 1
}

# Prefer a terminal-visible failure instead of silently doing nothing.
command -v git >/dev/null 2>&1 || fail "Git is not installed. Install git and try again."

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
        say "Synchronizing the local project with origin/${BRANCH}..."
        say "Local tracked changes are intentionally discarded; GitHub main is the source of truth."
        git -C "${PROJECT_DIR}" reset --hard "origin/${BRANCH}" ||
            fail "Could not reset the local repository to origin/${BRANCH}."
        git -C "${PROJECT_DIR}" clean -fd ||
            fail "Could not remove local untracked files."
    else
        say "Already up to date."
    fi
fi

[[ -f "${PROJECT_DIR}/project.godot" ]] ||
    fail "project.godot was not found after update."

say "Godot: $("${GODOT_BIN}" --version 2>/dev/null || true)"
say "Project: ${PROJECT_DIR}"

case "${MODE}" in
    game)
        say "Starting ACORN HUNTER..."
        exec "${GODOT_BIN}" --path "${PROJECT_DIR}"
        ;;
    editor)
        say "Opening the project in Godot Editor..."
        exec "${GODOT_BIN}" --editor --path "${PROJECT_DIR}"
        ;;
    *)
        fail "Unknown mode '${MODE}'. Use 'editor' or 'game'."
        ;;
esac
