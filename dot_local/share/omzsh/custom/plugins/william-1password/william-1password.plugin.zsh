#!/bin/zsh

opswitch() {
  command -v op >/dev/null 2>&1 || return 1

  local account
  account=$(op account list --format json 2>/dev/null | jq -r '.[].url' | fzf --header "Select 1Password Account" --reverse)
  [[ -n "$account" ]] && export OP_ACCOUNT="$account" && echo "Switched to: $account"
}

opsignin() {
  command -v op >/dev/null 2>&1 || return 1

  op account get >/dev/null 2>&1 && echo "Already signed in to $(op account get --format json | jq -r '.url')" || eval "$(op signin)"
}

chezmoi() {
  local OP_CHEZMOI_ACCOUNT="${CHEZMOI_1PASSWORD_ACCOUNT:-}"
  [[ -n "$OP_CHEZMOI_ACCOUNT" ]] && export OP_ACCOUNT="$OP_CHEZMOI_ACCOUNT"
  command chezmoi "$@"
}
