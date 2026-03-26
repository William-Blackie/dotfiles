# Dotfiles

macOS dotfiles managed with GNU Stow.

Each top-level directory is a stow package. Files inside a package map directly into `$HOME`.

Examples:

- `zsh/.zshrc` -> `~/.zshrc`
- `shell/.zshenv` -> `~/.zshenv`
- `git/.config/git/commit-template.txt` -> `~/.config/git/commit-template.txt`
- `nvim/.config/nvim/` -> `~/.config/nvim/`

## Packages

- `zsh`
- `shell`
- `tmux`
- `kitty`
- `starship`
- `nvim`
- `git`
- `bat`
- `fzf`

## Workflow

```bash
cd ~/.dotfiles
make edit
```

Edit the files in this repo directly. That is the source of truth.

When you want to apply changes:

```bash
make reinstall
```

`make reinstall` does two things:

1. normalizes any existing symlink that already points into `~/.dotfiles` so it is relative and stow-managed cleanly
2. restows every package

If you are setting up a machine from scratch:

```bash
make setup
```

That installs packages from the [Brewfile](/Users/william/.dotfiles/Brewfile), stows the dotfiles, and runs a small post-install bootstrap for zinit, tmux TPM, and bat cache.

## Commands

```bash
make help
make install
make reinstall
make uninstall
make edit
make status
make test
make ci
```

Notes:

- `make install` backs up conflicting files from `$HOME` before stowing
- `make reinstall` is the normal command after edits or pulls
- `make status` shows whether a dry-run stow is clean
- `make test` runs smoke tests for the repo workflow

## Neovim

The Neovim config lives in [nvim/.config/nvim](/Users/william/.dotfiles/nvim/.config/nvim).

Edit it from this repo like everything else:

```bash
make edit
```

After pulling Neovim changes, run:

```vim
:Lazy sync
```

## Stow Rules

- keep tracked dotfile links relative
- edit files in `~/.dotfiles`, not generated copies under `$HOME`
- if a target in `$HOME` is not stow-managed yet, `make install` will back it up before linking

That is the whole model. The repo should stay declarative and boring.
