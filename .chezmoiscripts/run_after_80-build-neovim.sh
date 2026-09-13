#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="${HOME}/.local/src/neovim"
INSTALL_PREFIX="${HOME}/.local"
BUILD_TYPE="RelWithDebInfo"
STATE_DIR="${HOME}/.local/state/chezmoi"
STAMP_FILE="${STATE_DIR}/neovim-build.txt"
BRANCH_NAME="release-0.12"

if [[ ! -d "$REPO_DIR/.git" ]]; then
    exit 0
fi

for cmd in git make cmake; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Skipping Neovim build: missing required command: $cmd"
        exit 0
    }
done

mkdir -p "$INSTALL_PREFIX/bin" "$STATE_DIR"

# Runs git in the Neovim checkout without reading global git config.
#
# Globals:
#   REPO_DIR
# Arguments:
#   Git subcommand and arguments.
# Outputs:
#   Writes git output to stdout/stderr.
# Returns:
#   The wrapped git command's exit status.
git_neovim() {
    GIT_CONFIG_GLOBAL=/dev/null git -C "$REPO_DIR" "$@"
}

if git_neovim fetch --force origin "refs/heads/${BRANCH_NAME}:refs/remotes/origin/${BRANCH_NAME}"; then
    echo "Neovim repository updated successfully."
else
    echo "Skipping Neovim build: unable to fetch latest changes from origin"
    exit 0
fi

if git_neovim show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    git_neovim switch "$BRANCH_NAME"
else
    git_neovim switch --track "origin/${BRANCH_NAME}"
fi

git_neovim merge --ff-only "origin/${BRANCH_NAME}"

HEAD="$(git_neovim rev-parse HEAD)"
STAMP_CONTENT=$'repo='"$REPO_DIR"$'\nhead='"$HEAD"$'\nprefix='"$INSTALL_PREFIX"$'\nbuild_type='"$BUILD_TYPE"

if [[ -x "$INSTALL_PREFIX/bin/nvim" && -f "$STAMP_FILE" ]] && [[ "$(cat "$STAMP_FILE")" == "$STAMP_CONTENT" ]]; then
    exit 0
fi

echo "Building Neovim from $REPO_DIR at $HEAD..."
make -C "$REPO_DIR" distclean
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" install
printf '%s\n' "$STAMP_CONTENT" >"$STAMP_FILE"
