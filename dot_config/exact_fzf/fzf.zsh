#!/bin/zsh

# fzf registers zle widgets, so skip it outside real interactive terminals.
if [[ ! -o interactive || ! -t 0 || ! -t 1 ]]; then
  return 0 2>/dev/null || exit 0
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
