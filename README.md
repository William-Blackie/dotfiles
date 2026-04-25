# Dotfiles

MacOS-first dotfiles managed by [chezmoi](https://www.chezmoi.io/).

The chezmoi source directory is `~/.dotfiles`. Most config lives under
`dot_config/exact_*`, which means chezmoi treats those directories as the full
desired state and removes unmanaged files inside them on apply.

## New Machine

Install Homebrew, then run:

```sh
brew install chezmoi git
chezmoi init git@github.com:williamblackie/dotfiles.git \
  --source ~/.dotfiles \
  --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

On a second machine where the repo already exists:

```sh
chezmoi init --source ~/.dotfiles \
  --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

`chezmoi apply` installs Homebrew packages and casks, applies config, fetches
externals, and rebuilds generated caches when relevant inputs change.

## Daily Use

```sh
chezmoi diff      # preview changes to $HOME
chezmoi apply     # apply this repo to $HOME
chezmoi status    # show drift
chezmoi unmanaged ~/.config/nvim
```

Edit files in `~/.dotfiles`, then apply. If a tool writes useful config back
into `$HOME`, copy or add it back into `~/.dotfiles` so the repo stays the
source of truth.

## 1Password And SSH

SSH is wired to the 1Password SSH agent through `private_dot_ssh/config.tmpl`.
The repo only stores the generic socket path.

Local 1Password state is intentionally not managed:

```sh
~/.config/1Password/ssh/agent.toml
```

Set up keys in the 1Password app on each machine, enable the SSH agent, and keep
key/vault/account selection local to that machine. Do not add `agent.toml`,
private keys, GitHub tokens, or `gh` auth state to this repo.

Optional per-machine SSH overrides go here:

```sh
~/.ssh/config.local
```

## Neovim

Neovim config lives in:

```sh
dot_config/exact_nvim
```

LazyVim lock/state files are symlinked back into the repo under
`dot_config/exact_nvim/private_data`, so normal Lazy writes are preserved.

Useful commands:

```sh
nvim
# then inside nvim:
# :Lazy sync
```
