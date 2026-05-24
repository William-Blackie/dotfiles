#!/usr/bin/env bash

# TODO: figure out right command
command -v rust >/dev/null 2>&1 || {
    echo "Skipping Rust install, already installed"
    exit 0
}

# https://rust-lang.org/learn/get-started/
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
