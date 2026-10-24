#!/usr/bin/env bash

set -euo pipefail

SRC_DIR="$HOME/.local/src"
LUA_VERSION="5.1.5"
LUA_SHA256="2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333"
LUA_ARCHIVE="lua-${LUA_VERSION}.tar.gz"
LUA_SRC_DIR="${SRC_DIR}/lua-${LUA_VERSION}"
BUILD_DEST_DIR="${SRC_DIR}/lua5.1/build"
BIN_DIR="$HOME/.local/bin"

if [[ -x "${BIN_DIR}/lua5.1" ]] && "${BIN_DIR}/lua5.1" -v 2>&1 | grep -q "Lua 5.1"; then
    exit 0
fi

for cmd in make tar; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Skipping Lua build: missing required command: $cmd"
        exit 0
    }
done

mkdir -pv "${SRC_DIR}"
mkdir -pv "${BIN_DIR}"
cd "${SRC_DIR}"

if [[ ! -f "$LUA_ARCHIVE" ]]; then
    if command -v curl >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 --fail --show-error --location \
            --output "$LUA_ARCHIVE" \
            "https://www.lua.org/ftp/${LUA_ARCHIVE}"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$LUA_ARCHIVE" "https://www.lua.org/ftp/${LUA_ARCHIVE}"
    else
        echo "Skipping Lua build: missing required command: curl or wget"
        exit 0
    fi
fi

if command -v shasum >/dev/null 2>&1; then
    actual_sha="$(shasum -a 256 "$LUA_ARCHIVE" | awk '{ print $1 }')"
elif command -v sha256sum >/dev/null 2>&1; then
    actual_sha="$(sha256sum "$LUA_ARCHIVE" | awk '{ print $1 }')"
else
    echo "Skipping Lua build: missing required command: shasum or sha256sum"
    exit 0
fi

if [[ "$actual_sha" != "$LUA_SHA256" ]]; then
    echo "Lua archive checksum mismatch."
    exit 1
fi

tar xzf "$LUA_ARCHIVE"

cd "$LUA_SRC_DIR"

case "$(uname -s)" in
    Darwin) make_target="macosx" ;;
    Linux) make_target="linux" ;;
    *) make_target="posix" ;;
esac

make "$make_target"
make INSTALL_TOP="${BUILD_DEST_DIR}" install

# Create a symlink for lua5.1 in the bin directory
ln -sf "${BUILD_DEST_DIR}/bin/lua" "${BIN_DIR}/lua5.1"

# cleanup source files
rm -rf "${SRC_DIR:?}/${LUA_ARCHIVE:?}" "${LUA_SRC_DIR:?}"

if ! "${BIN_DIR}/lua5.1" -v >/dev/null 2>&1; then
    echo "Lua install not found."
    exit 1
fi
