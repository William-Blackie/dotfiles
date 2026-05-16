#!/bin/zsh

export EDITOR="nvim"
export VISUAL="nvim"
export BAT_THEME="Catppuccin Mocha"
export EZA_COLORS="uu=36:gu=37:sn=32:sb=32:da=34:ur=34:uw=35:ux=36:ue=36:gr=34:gw=35:gx=36:tr=34:tw=35:tx=36:"

alias c="clear"
alias vim="nvim"
alias vimdiff="nvim -d"
command -v bat >/dev/null 2>&1 && alias cat="bat -pp"
command -v lazygit >/dev/null 2>&1 && alias lg="lazygit"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_CLI_HINTS=false
export COMPOSE_MENU=false

if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_DEFAULT_OPTS=" \
--height=40% --layout=reverse --border --info=inline-right \
--color=bg:#1e1e2e,bg+:#313244,spinner:#f5c2e7,hl:#89b4fa \
--color=fg:#cdd6f4,header:#94e2d5,info:#bac2de,pointer:#f5e0dc \
--color=marker:#a6e3a1,fg+:#f5e0dc,prompt:#89b4fa,hl+:#cba6f7,border:#45475a"
fi

_william_configure_keybindings() {
  bindkey -v
  export KEYTIMEOUT=1
  autoload -Uz edit-command-line up-line-or-beginning-search down-line-or-beginning-search
  zle -N edit-command-line
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey -M vicmd 'v' edit-command-line
  bindkey '^p' up-line-or-beginning-search
  bindkey '^n' down-line-or-beginning-search
  bindkey -M vicmd '^p' up-line-or-beginning-search
  bindkey -M vicmd '^n' down-line-or-beginning-search
}
_william_configure_keybindings
zvm_after_init() { _william_configure_keybindings }

if [[ -z "$STARSHIP_SHELL" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if [[ -o login ]]; then
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  elif command -v eza >/dev/null 2>&1; then
    eza -lah --git --group-directories-first --icons --no-user --no-time -TL 1
  fi
fi
