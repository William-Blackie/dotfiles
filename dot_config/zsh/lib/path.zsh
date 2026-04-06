# Single source of truth for shell PATH.
# Put the tools you actually want first and let zsh dedupe the rest.

typeset -U path PATH

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export NVM_DIR="$HOME/.nvm"
export PYENV_ROOT="$HOME/.pyenv"
export PYENV_DISABLE_AUTO_REHASH=1

typeset -a preferred_path
preferred_path=(
  "$HOME/.local/bin"
  "$HOME/.local/share/nvim/mason/bin"
  "$HOME/bin"
  "$PYENV_ROOT/shims"
  "$PYENV_ROOT/bin"
  "$HOME/.cargo/bin"
  "$HOME/.go/bin"
)

if [[ -r "$NVM_DIR/alias/default" ]]; then
  node_version="$(<"$NVM_DIR/alias/default")"
  if [[ -d "$NVM_DIR/versions/node/$node_version/bin" ]]; then
    preferred_path=("$NVM_DIR/versions/node/$node_version/bin" "${preferred_path[@]}")
  fi
fi

path=("${preferred_path[@]}" "${path[@]}")
export PATH
