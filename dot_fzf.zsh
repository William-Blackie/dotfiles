# Setup fzf
# ---------
if [[ -d "/opt/homebrew/opt/fzf/bin" ]]; then
  FZF_BIN="/opt/homebrew/opt/fzf/bin"
elif [[ -d "/usr/local/opt/fzf/bin" ]]; then
  FZF_BIN="/usr/local/opt/fzf/bin"
fi
if [[ -n "${FZF_BIN:-}" && ! "$PATH" == *"$FZF_BIN"* ]]; then
  PATH="${PATH:+${PATH}:}$FZF_BIN"
fi
unset FZF_BIN

source <(fzf --zsh)
