#!/bin/sh
# Shared by zsh and chezmoi's bootstrap scripts.
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Keep these tools separate from manually installed Nix packages.
export DOTFILES_NIX_PROFILE="$HOME/.local/state/nix/profiles/dotfiles"
export PATH="$DOTFILES_NIX_PROFILE/bin:$PATH"
