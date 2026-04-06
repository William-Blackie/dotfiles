# Dotfiles

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/).

The source of truth is [/.dotfiles](/Users/william/.dotfiles), stored in chezmoi source-state format. Repo-only files such as [Makefile](/Users/william/.dotfiles/Makefile), [scripts](/Users/william/.dotfiles/scripts), and [README.md](/Users/william/.dotfiles/README.md) are ignored by [/.chezmoiignore](/Users/william/.dotfiles/.chezmoiignore) and are not applied into `$HOME`.

Examples:

- [dot_zshrc](/Users/william/.dotfiles/dot_zshrc) -> `~/.zshrc`
- [dot_zshenv](/Users/william/.dotfiles/dot_zshenv) -> `~/.zshenv`
- [dot_config/nvim](/Users/william/.dotfiles/dot_config/nvim) -> `~/.config/nvim`
- [dot_config/zsh/lib/path.zsh](/Users/william/.dotfiles/dot_config/zsh/lib/path.zsh) -> `~/.config/zsh/lib/path.zsh`
- [dot_config/git/commit-template.txt](/Users/william/.dotfiles/dot_config/git/commit-template.txt) -> `~/.config/git/commit-template.txt`

## Workflow

```bash
cd ~/.dotfiles
make edit
```

Edit the files in this repo directly. That is the source of truth.

When you want to apply changes:

```bash
make apply
```

This runs:

```bash
chezmoi --source ~/.dotfiles apply
```

If you want to inspect pending changes first:

```bash
make diff
```

If you are setting up a machine from scratch:

```bash
make setup
```

That installs packages from [Brewfile](/Users/william/.dotfiles/Brewfile), builds Neovim from the upstream git repo into `~/.local/bin`, applies the chezmoi source state, and then runs the small post-install bootstrap for zinit, tmux TPM, and bat cache.

## Commands

```bash
make setup
make build-nvim
make apply
make diff
make edit
make status
make ci
```

Notes:

- `make link`, `make install`, and `make reinstall` are aliases for `make apply`
- `make status` shows both `chezmoi status` and `chezmoi doctor`
- `make build-nvim` builds Neovim from git into `~/.local/bin/nvim`

## Neovim

The Neovim config lives in [dot_config/nvim](/Users/william/.dotfiles/dot_config/nvim).

Edit it from this repo like everything else:

```bash
make edit
```

After pulling Neovim changes, run:

```vim
:Lazy sync
```
