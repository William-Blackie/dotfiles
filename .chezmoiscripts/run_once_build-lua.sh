#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$HOME/.local/src"
BUILD_DEST_DIR="${SRC_DIR}/lua5.1/build"
BIN_DIR="$HOME/.local/bin"

command -v make >/dev/null 2>&1 || {
    echo "Skipping Lua build: missing required command: make"
    exit 0
}

command -v wget >/dev/null 2>&1 || {
    echo "Skipping Lua build: missing required command: wget"
    exit 0
}

mkdir -pv "${SRC_DIR}"
mkdir -pv "${BIN_DIR}"
cd "${SRC_DIR}"

# Download and extract Lua 5.1.5
wget -nc https://www.lua.org/ftp/lua-5.1.5.tar.gz
tar xzf lua-5.1.5.tar.gz

cd lua-5.1.5

make macosx
make INSTALL_TOP="${BUILD_DEST_DIR}" install

# Create a symlink for lua5.1 in the bin directory
ln -sf "${BUILD_DEST_DIR}/bin/lua" "${BIN_DIR}/lua5.1"

# cleanup source files
rm "${SRC_DIR}/lua-5.1.5.tar.gz"

if ! "${BIN_DIR}/lua5.1" -v >/dev/null 2>&1; then
    echo "Lua install not found."
    exit 1
fi
