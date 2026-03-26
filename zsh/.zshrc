setopt extendedglob

##### Modular Config Loader
# Load machine-independent paths first
source "$HOME/.dotfiles/zsh/lib/path.zsh"

##### Python / pyenv (Lazy-loaded for speed)
# Shims are already in PATH from path.zsh for transparent use.
# Shell integration is loaded only when the pyenv command is first called.
if command -v pyenv >/dev/null 2>&1; then
  pyenv() {
    unset -f pyenv
    eval "$(command pyenv init -)"
    pyenv "$@"
  }
fi

##### Go
if command -v go >/dev/null 2>&1; then
  export GOPATH="$HOME/go"
  export PATH="$GOPATH/bin:$PATH"
fi

# ... Load any other modular configs (Tracked)
for config_file in "$HOME/.dotfiles/zsh/lib"/*.zsh(N); do
  if [[ "$config_file" != */path.zsh ]]; then
    source "$config_file"
  fi
done

# Load machine-local drop-ins (Untracked)
for local_config in "$HOME/.zshrc.d"/*.zsh(N); do
  source "$local_config"
done

# Optional private/work overrides (kept separate if needed)
for work_config in "$HOME/.dotfiles-work/zsh"/*.zsh(N); do
  source "$work_config"
done

##### Zinit (plugin manager)
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  if command -v git >/dev/null 2>&1; then
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi
fi
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"
fi

##### Plugins (work-focused)
if (( $+functions[zinit] )); then
  zinit light zsh-users/zsh-completions
  zinit light zsh-users/zsh-autosuggestions

  # OMZ snippets (non-theme)
  zinit snippet OMZL::git.zsh
  zinit snippet OMZP::git
  zinit snippet OMZP::sudo
  zinit snippet OMZP::kubectl
  zinit snippet OMZP::kubectx
  zinit snippet OMZP::command-not-found

  # Annexes
  zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust
fi

##### Completions
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)

# Optimize compinit by only running it once a day
ZCOMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -s "$ZCOMPDUMP" && (! -f "$ZCOMPDUMP.zwc" || "$ZCOMPDUMP" -nt "$ZCOMPDUMP.zwc") ]]; then
  zcompile "$ZCOMPDUMP"
fi

if [[ -n "$ZCOMPDUMP"(#qN.m-1) ]]; then
  autoload -Uz compinit && compinit -C
else
  autoload -Uz compinit && compinit
fi
zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '%F{245}%d%f'
zstyle ':completion:*:warnings' format '%F{203}no matches for:%f %d'

# fzf integration (load before fzf-tab so fzf-tab can wrap it)
if command -v fzf >/dev/null 2>&1; then
  [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  # Catppuccin Mocha theme
  export FZF_DEFAULT_OPTS=" \
--height=40% --layout=reverse --border --info=inline-right \
--color=bg:#1e1e2e,bg+:#313244,spinner:#f5c2e7,hl:#89b4fa \
--color=fg:#cdd6f4,header:#94e2d5,info:#bac2de,pointer:#f5e0dc \
--color=marker:#a6e3a1,fg+:#f5e0dc,prompt:#89b4fa,hl+:#cba6f7,border:#45475a"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# fzf-tab (load after compinit and fzf)
if (( $+functions[zinit] )); then
  zinit light Aloxaf/fzf-tab
fi
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border

# Vi-mode configuration
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk # allow 'jk' to exit insert mode
ZVM_LINE_BEFORE_PROMPT=false     # keep prompt compact

# gh completion (lazy-loaded on first use)
if command -v gh >/dev/null 2>&1; then
  _gh_load_completion() {
    eval "$(command gh completion -s zsh)"
    # After loading, call the real completion function
    _gh "$@"
  }
  compdef _gh_load_completion gh
fi

##### Prompt (Starship + Catppuccin)
if [[ -z "$STARSHIP_SHELL" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

##### Keybindings & history (vim-style)
# ... (rest of the file)
# (I'll need to find where scw is)


##### Keybindings & history (vim-style)
bindkey -v
export KEYTIMEOUT=1   # make Esc feel instant

# Edit command line in $EDITOR with 'v' in vicmd mode
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# History search (prefix-aware)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^p' up-line-or-beginning-search
bindkey '^n' down-line-or-beginning-search
bindkey -M vicmd '^p' up-line-or-beginning-search
bindkey -M vicmd '^n' down-line-or-beginning-search

HISTSIZE=500000
SAVEHIST=$HISTSIZE
HISTFILE=~/.zsh_history
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups \
       hist_save_no_dups hist_ignore_dups hist_find_no_dups

##### Aliases & Helpers
alias c="clear"

# Command Cheatsheet (searchable via fzf)
unalias cheatsheet 2>/dev/null
cheatsheet() {
  local base_content=$(cat << 'EOF'
==== Navigation & Core ====
ls    - eza (modern ls) with icons and git status
c     - clear terminal
vim   - neovim (modern vim)
lg    - lazygit (terminal UI for git)

==== Tmux ====
pfs   - fuzzy project switcher (searches ~/Projects)
start - attach or create 'main' tmux session
tmx   - attach or create tmux session (arg: name)
tmn   - create new unique tmux session (arg: base_name)
tml   - list active tmux sessions

==== Docker ====
dc    - docker compose
dcu   - docker compose up -d (detached, remove orphans)
dcd   - docker compose down (remove orphans)

==== Git Core ====
gs    - git status
ga    - git add
gc    - git commit
gpl   - git pull
gph   - git push
gd    - git diff
glog  - git log (graph)
ggb   - fuzzy branch switcher

==== Grove / Worktrees ====
pfs   - open Grove project picker
wtl   - list worktrees and context
wta   - create a new worktree branch
wts   - start worktree services
wtr   - restart current worktree session
wtx   - stop worktree services
wtp   - promote worktree changes back to branch
wtcl  - clean worktree compose state
wtpj  - run worktree helpers for a named project

==== AI / Gemini ====
ai      - run gemini CLI
aip     - run gemini CLI in prompt mode
gai     - generate AI commit message for staged changes
gge     - explain git diff/commit (arg: ref or HEAD)
explain - explain a command using Gemini (arg: command or last one)

==== Secrets ====
vset    - store local config blobs in 1Password or Bitwarden

==== Bluetooth & Audio ====
bt        - toggle bluetooth device connection (fzf)
audio     - switch audio input/output source (fzf)

==== Kubernetes ====
k       - kubectl (alias)
kkx     - switch context (interactive fzf)
kkn     - switch namespace (interactive fzf)
kkl     - tail pod logs (interactive fzf)
kke     - explain kube resource/error (arg: context or last cmd)

==== Reference ====
v       - edit current command line in nvim (in vicmd mode)
vimhelp - search vim motions cheatsheet

==== Neovim AI (Gemini/OpenAI) ====
Ctrl-g c - Gemini: New chat (vsplit)
Ctrl-g t - Gemini: Toggle chat
Ctrl-g r - Gemini: Rewrite selection (v-mode)
Ctrl-o c - OpenAI: New chat (vsplit)
Ctrl-o t - OpenAI: Toggle chat
Ctrl-o r - OpenAI: Rewrite selection (v-mode)
EOF
)
  local local_content=""
  [[ -f ~/.cheatsheet.local ]] && local_content=$(cat ~/.cheatsheet.local)

  local selected=$(printf "%s\n%s" "$base_content" "$local_content" | fzf --height=100% --header "Terminal Cheatsheet" --reverse)
  if [[ -n "$selected" ]]; then
    local cmd=$(echo "$selected" | awk '{print $1}')
    if [[ "$cmd" != "===="* ]]; then
      print -z "$cmd"
    fi
  fi
}


# Vim Motion Quick Reference (searchable via fzf)
unalias vimhelp 2>/dev/null
vimhelp() {
  local selected=$(cat << 'EOF' | fzf --height=100% --header "Vim Motion Quick Reference" --reverse
w - next word | b - back word | e - end of word
0 - start of line | $ - end of line | ^ - first non-blank
f{char} - jump forward to char | t{char} - jump until char
F{char} - jump backward to char | T{char} - jump back until char
; - repeat last f/t jump | , - reverse last f/t jump
dw - delete word | cw - change word | de - delete to end of word
df{char} - delete forward to char | dt{char} - delete until char
ci" - change inside quotes | ca" - change around quotes
ci( - change inside parens | ca( - change around parens
G - bottom of file | gg - top of file | {line}G - go to line
EOF
)
  if [[ -n "$selected" ]]; then
    local motion=$(echo "$selected" | awk '{print $1}')
    print -z "$motion"
  fi
}

if command -v eza >/dev/null 2>&1; then
  alias ls="eza -lah --git --group-directories-first --icons"
fi
if command -v bat >/dev/null 2>&1; then
  alias cat="bat -pp"
fi
if command -v nvim >/dev/null 2>&1; then
  alias vim="nvim"
fi
if command -v lazygit >/dev/null 2>&1; then
  alias lg="lazygit"
fi

# Bluetooth & Audio helpers (macOS)
# Functions 'bt' and 'audio' are defined in zsh/lib/audio.zsh

if command -v docker >/dev/null 2>&1; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
  export DOCKER_CLI_HINTS=false
  export COMPOSE_MENU=false
  alias dc="docker compose"
  alias dcu="docker compose up -d --remove-orphans"
  alias dcd="docker compose down --remove-orphans"
fi

alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gca="git commit -a"
alias gcm="git commit -m"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gbd="git branch -d"
alias gbr="git branch"
alias gpl="git pull"
alias gph="git push"
alias gsh="git stash"
alias gshp="git stash pop"
alias gshl="git stash list"
alias gd="git diff"
alias gds="git diff --staged"
alias glog="git log --oneline --graph --decorate --all"

##### Node.js / nvm (lazy-loaded)
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _nvm_load() {
    # If the real nvm is already in the path, it should already be handled.
    # But lazy functions are useful for full nvm management.
    unset -f nvm node npm npx yarn pnpm corepack
    \. "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"
  }
  nvm()      { _nvm_load; nvm "$@" }
  node()     { _nvm_load; node "$@" }
  npm()      { _nvm_load; npm "$@" }
  npx()      { _nvm_load; npx "$@" }
  yarn()     { _nvm_load; yarn "$@" }
  pnpm()     { _nvm_load; pnpm "$@" }
  corepack() { _nvm_load; corepack "$@" }
fi

##### Terminal Greeting
if [[ -o login ]]; then
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  elif command -v eza >/dev/null 2>&1; then
    # Fallback to a directory listing
    eza -lah --git --group-directories-first --icons --no-user --no-time -TL 1
  fi
fi



##### Machine-local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

##### Editor
export EDITOR="nvim"
export VISUAL="nvim"

##### Tool defaults
export BAT_THEME="Catppuccin Mocha"
export EZA_COLORS="uu=36:gu=37:sn=32:sb=32:da=34:ur=34:uw=35:ux=36:ue=36:gr=34:gw=35:gx=36:tr=34:tw=35:tx=36:"

##### Zsh syntax highlighting & Vi Mode
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]="fg=#89b4fa,bold"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=#cba6f7"
ZSH_HIGHLIGHT_STYLES[alias]="fg=#f9e2af"
ZSH_HIGHLIGHT_STYLES[path]="fg=#94e2d5"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#f38ba8,bold"
if (( $+functions[zinit] )); then
  zinit light zsh-users/zsh-syntax-highlighting
  zinit light jeffreytse/zsh-vi-mode
fi


