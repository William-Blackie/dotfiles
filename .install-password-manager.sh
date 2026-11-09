#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dot_config/shell/nix.sh
# shellcheck disable=SC1091
. "$source_dir/dot_config/shell/nix.sh"

[[ -x "$DOTFILES_NIX_PROFILE/bin/op" ]] && exit 0
exec bash "$source_dir/.install-nix-packages.sh" onepassword
