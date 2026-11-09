#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

# Use functions so a system Nix profile cannot override these test doubles.
nix() {
    printf '%s\n' "$*" >>"$TEST_NIX_LOG"
    [[ "${TEST_BUILD_FAIL:-0}" == 0 ]] || return 1
    printf '/nix/store/test-dotfiles-tools\n'
}
nix-env() {
    printf '%s\n' "$*" >>"$TEST_PROFILE_LOG"
}
export -f nix nix-env
export TEST_NIX_LOG="$test_dir/nix.log"
export TEST_PROFILE_LOG="$test_dir/profile.log"

# Give child processes a disposable home without changing this shell's HOME.
env HOME="$test_dir/home" bash "$source_dir/.install-password-manager.sh"
grep -q '#onepassword' "$TEST_NIX_LOG"
grep -q -- "--profile $test_dir/home/.local/state/nix/profiles/dotfiles --set /nix/store/test-dotfiles-tools" "$TEST_PROFILE_LOG"

# A working managed CLI avoids both network/evaluation and profile mutations.
mkdir -p "$test_dir/home/.local/state/nix/profiles/dotfiles/bin"
printf '#!/bin/sh\nexit 0\n' >"$test_dir/home/.local/state/nix/profiles/dotfiles/bin/op"
chmod +x "$test_dir/home/.local/state/nix/profiles/dotfiles/bin/op"
: >"$TEST_NIX_LOG"
: >"$TEST_PROFILE_LOG"
env HOME="$test_dir/home" bash "$source_dir/.install-password-manager.sh"
[[ ! -s "$TEST_NIX_LOG" && ! -s "$TEST_PROFILE_LOG" ]]

# A failed full build must not replace the working profile.
if env HOME="$test_dir/home" TEST_BUILD_FAIL=1 bash "$source_dir/.install-nix-packages.sh"; then
    echo "Expected the failed build to stop installation" >&2
    exit 1
fi
[[ ! -s "$TEST_PROFILE_LOG" ]]

env HOME="$test_dir/home" bash "$source_dir/.install-nix-packages.sh"
grep -q '#default' "$TEST_NIX_LOG"
grep -q -- '--set /nix/store/test-dotfiles-tools' "$TEST_PROFILE_LOG"
echo "Nix bootstrap tests passed"
