#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

echo "Running post-install setup..."

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]] && command -v git > /dev/null 2>&1; then
  echo "Installing zinit..."
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

TPM_HOME="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_HOME" ]] && command -v git > /dev/null 2>&1; then
  echo "Installing tmux TPM..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_HOME"
fi

if command -v bat > /dev/null 2>&1 && [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/bat/themes" ]]; then
  echo "Rebuilding bat cache..."
  bat cache --build
fi

echo "Post-install setup complete."
echo "Next:"
echo "  1. Restart your shell or run: source ~/.zshrc"
echo "  2. In tmux, press prefix + I to install plugins"
echo "  3. In Neovim, run :Lazy sync"
