#!/bin/zsh

[[ -f "$ZDOTDIR/.zshrc.local" ]] && source "$ZDOTDIR/.zshrc.local"

for local_config in "$ZDOTDIR/.zshrc.d"/*.zsh(N) "$HOME/dotfiles-work/zsh"/*.zsh(N); do
  source "$local_config"
done
