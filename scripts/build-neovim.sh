#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

REPO_URL="${NEOVIM_REPO_URL:-https://github.com/neovim/neovim.git}"
REPO_DIR="${NEOVIM_REPO_DIR:-$HOME/.local/src/neovim}"
INSTALL_PREFIX="${NEOVIM_INSTALL_PREFIX:-$HOME/.local}"
REF="${NEOVIM_REF:-stable}"
BUILD_TYPE="${NEOVIM_BUILD_TYPE:-RelWithDebInfo}"

require_cmd() {
  command -v "$1" > /dev/null 2>&1 || {
    echo "missing required command: $1"
    exit 1
  }
}

require_cmd git
require_cmd make
require_cmd cmake

mkdir -p "$(dirname "$REPO_DIR")" "$INSTALL_PREFIX/bin"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "Cloning Neovim ($REF) into $REPO_DIR..."
  rm -rf "$REPO_DIR"
  git clone --depth 1 --filter=blob:none --branch "$REF" --single-branch "$REPO_URL" "$REPO_DIR"
else
  echo "Using existing Neovim checkout at $REPO_DIR"
  if git -C "$REPO_DIR" diff --quiet && git -C "$REPO_DIR" diff --cached --quiet; then
    echo "Updating Neovim checkout..."
    git -C "$REPO_DIR" fetch --depth 1 origin "$REF"
    git -C "$REPO_DIR" checkout "$REF"
    if git -C "$REPO_DIR" show-ref --verify --quiet "refs/remotes/origin/$REF"; then
      git -C "$REPO_DIR" pull --ff-only --depth 1 origin "$REF"
    fi
  else
    echo "Skipping git update because the Neovim checkout has local changes."
  fi
fi

echo "Building Neovim from source..."
make -C "$REPO_DIR" distclean
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
make -C "$REPO_DIR" CMAKE_BUILD_TYPE="$BUILD_TYPE" CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" install

echo "Neovim installed to $INSTALL_PREFIX/bin/nvim"
