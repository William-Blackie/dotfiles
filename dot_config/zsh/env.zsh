#!/bin/zsh

typeset -U path PATH

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR%/}/xdg-runtime-$UID"
fi
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export ANDROID_USER_HOME="$XDG_DATA_HOME/android"
export AWS_CONFIG_FILE="$XDG_CONFIG_HOME/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME/aws/credentials"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
export CODEX_HOME="$XDG_CONFIG_HOME/codex"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export GEM_HOME="$XDG_DATA_HOME/gem"
export GEM_SPEC_CACHE="$XDG_CACHE_HOME/gem"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export GOPATH="$XDG_DATA_HOME/go"
export INPUTRC="$XDG_CONFIG_HOME/readline/inputrc"
export LESSHISTFILE="$XDG_STATE_HOME/lesshst"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
unset NPM_CONFIG_INIT_MODULE NPM_CONFIG_TMP
export NVM_DIR="$XDG_DATA_HOME/nvm"
export PERL_CPANM_HOME="$XDG_CACHE_HOME/cpanm"
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
export PNPM_HOME="$XDG_DATA_HOME/pnpm"
export PYTHON_HISTORY="$XDG_STATE_HOME/python_history"
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/config"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export SHELL_SESSIONS_DISABLE=1

if [[ "$OSTYPE" == darwin* ]]; then
  _op_ssh_sock="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
elif [[ "$OSTYPE" == linux* ]]; then
  _op_ssh_sock="$HOME/.1password/agent.sock"
fi
if [[ -n "${_op_ssh_sock:-}" && -S "$_op_ssh_sock" ]]; then
  export SSH_AUTH_SOCK="$_op_ssh_sock"
fi
unset _op_ssh_sock

preferred_path=(
  "$HOME/.local/bin"
  "$XDG_DATA_HOME/nvim/mason/bin"
  "$HOME/bin"
  "$PNPM_HOME/bin"
  "$CARGO_HOME/bin"
  "$GOPATH/bin"
)

if [[ -r "$NVM_DIR/alias/default" ]]; then
  _node_version="$(<"$NVM_DIR/alias/default")"
  [[ -d "$NVM_DIR/versions/node/$_node_version/bin" ]] && preferred_path=("$NVM_DIR/versions/node/$_node_version/bin" "${preferred_path[@]}")
fi
unset _node_version

path=("${preferred_path[@]}" "${path[@]}")
export PATH
