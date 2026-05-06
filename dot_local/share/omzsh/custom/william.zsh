#!/bin/zsh

export EDITOR="nvim"
export VISUAL="nvim"
export BAT_THEME="Catppuccin Mocha"
export EZA_COLORS="uu=36:gu=37:sn=32:sb=32:da=34:ur=34:uw=35:ux=36:ue=36:gr=34:gw=35:gx=36:tr=34:tw=35:tx=36:"

alias c="clear"
alias vim="nvim"
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

_configure_keybindings() {
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
_configure_keybindings
zvm_after_init() { _configure_keybindings }

if command -v kubectl >/dev/null 2>&1; then
  kkx() {
    local ctx
    ctx=$(kubectl config get-contexts -o name | fzf --header "Switch Kube Context" --reverse)
    [[ -n "$ctx" ]] && kubectl config use-context "$ctx"
  }

  kkn() {
    local ns
    ns=$(kubectl get namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | fzf --header "Switch Kube Namespace" --reverse)
    [[ -n "$ns" ]] && kubectl config set-context --current --namespace="$ns"
  }

  kkl() {
    local pod
    pod=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | fzf --header "Tail Pod Logs" --reverse)
    [[ -n "$pod" ]] && kubectl logs -f "$pod"
  }
fi

bt() {
  command -v blueutil >/dev/null 2>&1 || { echo "blueutil not found. Install it: brew install blueutil"; return 1; }

  local devices selected mac name conn_status
  devices=$(blueutil --paired | awk -F', ' '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /address: /) { a=$i; sub(/.*address: /, "", a) }
      if ($i ~ /name: /) { n=$i; sub(/.*name: /, "", n); gsub(/"/, "", n) }
    }
    if (a && n) print n " | " a
  }')
  selected=$(echo "$devices" | fzf --height=20% --layout=reverse --border --header "Bluetooth Devices")
  [[ -z "$selected" ]] && return

  mac=$(echo "$selected" | awk -F' | ' '{print $NF}')
  name=$(echo "$selected" | awk -F' | ' '{print $1}')
  conn_status=$(blueutil --is-connected "$mac")
  if [[ "$conn_status" == "1" ]]; then
    echo "Disconnecting $name..."
    blueutil --disconnect "$mac"
  else
    echo "Connecting to $name..."
    blueutil --connect "$mac"
  fi
}

audio() {
  command -v SwitchAudioSource >/dev/null 2>&1 || { echo "switchaudio-osx not found. Install it: brew install switchaudio-osx"; return 1; }

  local mode type current devices selected
  mode=$(echo "Output (Everything)\nInput (Mic)\nMute All\nUnmute All\nRestart Audio Engine" | fzf --height=15% --layout=reverse --border --header "Audio Management")
  [[ -z "$mode" ]] && return

  case "$mode" in
    *"Mute All"*)
      SwitchAudioSource -m mute -t output
      SwitchAudioSource -m mute -t input
      osascript -e "set volume with output muted"
      return
      ;;
    *"Unmute All"*)
      SwitchAudioSource -m unmute -t output
      SwitchAudioSource -m unmute -t input
      osascript -e "set volume without output muted"
      return
      ;;
    *"Restart Audio Engine"*)
      sudo killall coreaudiod
      return
      ;;
  esac

  type="output"
  [[ "$mode" == *"Input"* ]] && type="input"
  current=$(SwitchAudioSource -c -t "$type")
  devices=$(SwitchAudioSource -a -t "$type" | grep -v "$current")
  selected=$(echo "$devices" | fzf --height=20% --layout=reverse --border --header "Switch $mode to:")
  [[ -z "$selected" ]] && return

  if [[ "$type" == "output" ]]; then
    SwitchAudioSource -s "$selected" -t output
    SwitchAudioSource -s "$selected" -t system
  else
    SwitchAudioSource -s "$selected" -t input
  fi
}

opswitch() {
  local account
  account=$(op account list --format json 2>/dev/null | jq -r '.[].url' | fzf --header "Select 1Password Account" --reverse)
  [[ -n "$account" ]] && export OP_ACCOUNT="$account" && echo "Switched to: $account"
}

opsignin() {
  op account get >/dev/null 2>&1 && echo "Already signed in to $(op account get --format json | jq -r '.url')" || eval "$(op signin)"
}

export OP_PERSONAL_ACCOUNT="${CHEZMOI_1PASSWORD_ACCOUNT:-}"
export OP_WORK_ACCOUNT="${OP_WORK_ACCOUNT:-}"

_op_auto_switch() {
  [[ -z "$OP_PERSONAL_ACCOUNT" ]] && return
  case "$PWD" in
    "$HOME/.dotfiles"*|"$HOME/.local/share/chezmoi"*) export OP_ACCOUNT="$OP_PERSONAL_ACCOUNT" ;;
    *) [[ -n "$OP_WORK_ACCOUNT" ]] && export OP_ACCOUNT="$OP_WORK_ACCOUNT" || unset OP_ACCOUNT ;;
  esac
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _op_auto_switch
_op_auto_switch

chezmoi() {
  local original_account="${OP_ACCOUNT:-}"
  [[ -n "$OP_PERSONAL_ACCOUNT" ]] && export OP_ACCOUNT="$OP_PERSONAL_ACCOUNT"
  command chezmoi "$@"
  local exit_code=$?
  [[ -n "$original_account" ]] && export OP_ACCOUNT="$original_account" || { unset OP_ACCOUNT; _op_auto_switch; }
  return $exit_code
}

cheatsheet() {
  local selected cmd
  selected=$(
    cat <<'EOF' | fzf --height=100% --header "Terminal Cheatsheet" --reverse
ls    - eza with icons and git status
c     - clear terminal
vim   - neovim
lg    - lazygit
dco   - docker compose
dcupd - docker compose up -d
dcdn  - docker compose down
gst   - git status
ga    - git add
gc    - git commit
ggpull - pull current branch from origin
ggpush - push current branch to origin
gd    - git diff
glog  - git log graph
k     - kubectl
kkx   - switch kube context
kkn   - switch kube namespace
kkl   - tail pod logs
vimhelp - search vim motions
EOF
  )
  [[ -z "$selected" ]] && return
  cmd=$(echo "$selected" | awk '{print $1}')
  print -z "$cmd"
}

vimhelp() {
  local selected
  selected=$(
    cat <<'EOF' | fzf --height=100% --header "Vim Motion Quick Reference" --reverse
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
  [[ -n "$selected" ]] && print -z "$(echo "$selected" | awk '{print $1}')"
}

if [[ -o login ]]; then
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
  elif command -v eza >/dev/null 2>&1; then
    eza -lah --git --group-directories-first --icons --no-user --no-time -TL 1
  fi
fi

for local_config in "$ZDOTDIR/.zshrc.d"/*.zsh(N) "$HOME/.dotfiles-work/zsh"/*.zsh(N); do
  source "$local_config"
done
