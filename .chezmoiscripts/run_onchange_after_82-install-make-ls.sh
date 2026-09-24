#!/usr/bin/env bash
set -euo pipefail

MAKE_LS_VERSION="v0.1.23"
GO_BIN_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/go/bin"

if ! command -v go >/dev/null 2>&1; then
    echo "Cannot install make-ls: go is not available" >&2
    exit 1
fi

mkdir -p "$GO_BIN_DIR"
GOBIN="$GO_BIN_DIR" go install \
    "github.com/owenrumney/make-ls/cmd/make-ls@${MAKE_LS_VERSION}"
