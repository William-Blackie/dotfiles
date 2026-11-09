#!/bin/zsh

# Account IDs belong in the machine-local .zshenv.local file.
_op_account() {
  case "${1:-}" in
  work) print -r -- "${OP_WORK_ACCOUNT:?Set OP_WORK_ACCOUNT in .zshenv.local}" ;;
  personal) print -r -- "${OP_PERSONAL_ACCOUNT:?Set OP_PERSONAL_ACCOUNT in .zshenv.local}" ;;
  *) print -r -- "$1" ;;
  esac
}

opwork() {
  local account
  account="$(_op_account work)" || return 1
  command op --account "$account" "$@"
}

oppersonal() {
  local account
  account="$(_op_account personal)" || return 1
  command op --account "$account" "$@"
}

# Select by alias, account ID/URL, or interactively when no argument is supplied.
opswitch() {
  local account cmd
  if [[ $# -gt 0 ]]; then
    account="$(_op_account "$1")" || return 1
  else
    for cmd in op jq fzf; do
      command -v "$cmd" >/dev/null 2>&1 || {
        print -u2 "opswitch: missing required command: $cmd"
        return 1
      }
    done
    account=$(command op account list --format json | jq -r '.[].url' | fzf --header "Select 1Password Account" --reverse)
  fi
  [[ -n "$account" && "$account" != "null" ]] || return 1
  export OP_ACCOUNT="$account"
  print "Switched to: $account"
}

# Desktop app integration authenticates without exporting a session token.
opsignin() {
  local account
  local -a account_args
  account="$(_op_account "${1:-${OP_ACCOUNT:-}}")" || return 1
  [[ -n "$account" ]] && account_args=(--account "$account")
  command op signin "${account_args[@]}" >/dev/null || return
  command op whoami "${account_args[@]}"
}

# Scope the dotfiles account to this command; preserve the shell's selected account.
chezmoi() {
  if [[ -n "${CHEZMOI_1PASSWORD_ACCOUNT:-}" ]]; then
    OP_ACCOUNT="$CHEZMOI_1PASSWORD_ACCOUNT" command chezmoi "$@"
  else
    command chezmoi "$@"
  fi
}
