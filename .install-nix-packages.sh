#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dot_config/shell/nix.sh
# shellcheck disable=SC1091
. "$source_dir/dot_config/shell/nix.sh"

if ! command -v nix >/dev/null 2>&1; then
    echo "Install Nix first: https://nixos.org/download/ — then rerun chezmoi." >&2
    exit 1
fi

target="${1:-default}"
case "$target" in
    default | onepassword) ;;
    *)
        echo "Unknown Nix package set: $target" >&2
        exit 1
        ;;
esac

mkdir -p "$(dirname "$DOTFILES_NIX_PROFILE")"
store_path="$(nix --extra-experimental-features 'nix-command flakes' build \
    --no-write-lock-file --no-link --print-out-paths \
    "path:$source_dir/.nix#$target")"
# Switch only after the entire environment builds successfully; retain generations.
nix-env --profile "$DOTFILES_NIX_PROFILE" --set "$store_path"
