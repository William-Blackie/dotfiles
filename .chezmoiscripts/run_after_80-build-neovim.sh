#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="${HOME}/.local/src/neovim"
INSTALL_PREFIX="${HOME}/.local"
BUILD_TYPE="RelWithDebInfo"
STATE_DIR="${HOME}/.local/state/chezmoi"
STAMP_FILE="${STATE_DIR}/neovim-build.txt"

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

HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"
STAMP_CONTENT=$'repo='"$REPO_DIR"$'\nhead='"$HEAD"$'\nprefix='"$INSTALL_PREFIX"$'\nbuild_type='"$BUILD_TYPE"

if [[ -x "$INSTALL_PREFIX/bin/nvim" && -f "$STAMP_FILE" ]] && [[ "$(cat "$STAMP_FILE")" == "$STAMP_CONTENT" ]]; then
    exit 0
fi

echo "Building Neovim from $REPO_DIR at $HEAD..."
make -C "$REPO_DIR" distclean
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" install
printf '%s\n' "$STAMP_CONTENT" >"$STAMP_FILE"
