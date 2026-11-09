#!/bin/sh
# Shared by zsh and chezmoi's bootstrap scripts.
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Chezmoi can replace PATH while inheriting Nix's already-sourced flag.
if ! command -v nix >/dev/null 2>&1; then
    for nix_profile in "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile" "$HOME/.nix-profile" /nix/var/nix/profiles/default; do
        if [ -x "$nix_profile/bin/nix" ]; then
            export PATH="$nix_profile/bin:$PATH"
            break
        fi
    done
    unset nix_profile
fi

# Keep these tools separate from manually installed Nix packages.
export DOTFILES_NIX_PROFILE="$HOME/.local/state/nix/profiles/dotfiles"
export PATH="$DOTFILES_NIX_PROFILE/bin:$PATH"
