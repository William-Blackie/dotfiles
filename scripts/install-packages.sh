#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="$ROOT_DIR/Brewfile"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer currently supports macOS/Homebrew only."
  exit 1
fi

if ! command -v brew > /dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing packages from $BREWFILE..."
brew bundle --file="$BREWFILE"

echo "✅ Packages installed"
