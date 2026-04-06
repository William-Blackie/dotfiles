#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="$ROOT_DIR/Brewfile"

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin:$PATH"

brew_cmd() {
  if command -v brew > /dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return 0
  fi

  return 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Skipping package install: Homebrew bootstrap is macOS-only."
  exit 0
fi

if ! BREW_BIN="$(brew_cmd)"; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(brew_cmd)"
fi

echo "Installing packages from $BREWFILE..."
if "$BREW_BIN" list --versions lazygit > /dev/null 2>&1; then
  "$BREW_BIN" link --overwrite lazygit > /dev/null 2>&1 || true
fi
"$BREW_BIN" bundle --file="$BREWFILE"

echo "✅ Packages installed"
