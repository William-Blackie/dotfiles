# Dotfiles

MacOS dotfiles managed with [chezmoi](https://www.chezmoi.io/).

The source of truth is [/.dotfiles](.dotfiles), stored in chezmoi source-state
format. Repo-only files such as [Makefile](.dotfiles/Makefile) and
[README.md](README.md) are ignored by
[/.chezmoiignore](.dotfiles/.chezmoiignore) and are not applied into `$HOME`.

## Workflow

Edit files directly in this repo or using `chezmoi.nvim`.
Apply changes:

```bash
chezmoi init --source ~/.dotfiles --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

After the bootstrap step, plain `chezmoi` commands work because the repo owns
the config template in
[dot_config/chezmoi/chezmoi.toml.tmpl](.dotfiles/dot_config/chezmoi/chezmoi.toml.tmpl).

Inspect pending changes:

```bash
chezmoi diff
```

Setup a new machine:

```bash
chezmoi init --source ~/.dotfiles --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

That installs packages from
[.chezmoidata/packages.yaml](.dotfiles/.chezmoidata/packages.yaml), checks out
the Neovim source as a chezmoi external under `~/.local/src/neovim`, builds it
into `~/.local/bin`, and applies the chezmoi source state.

`chezmoi apply` now also owns the bootstrap bits that used to live in ad-hoc
shell glue:

- Homebrew package install is run via a `run_onchange_` script keyed off
  [.chezmoidata/packages.yaml](.dotfiles/.chezmoidata/packages.yaml)
- macOS apps are installed as Homebrew casks; there is no separate DMG
  installer script
- zinit and tmux TPM are fetched as chezmoi externals
- Neovim source is fetched as a chezmoi `git-repo` external and built after
  apply when the checked-out Neovim HEAD differs from the build stamp
- bat cache rebuild runs via a `run_onchange_after_` script when the bat config
  changes
- zsh, git, tmux, readline, ripgrep, and several tool paths are wired for XDG
  locations, with compatibility symlinks where data is intentionally left in
  place under `~/.*`

## Common Commands

```bash
# Apply dotfiles
chezmoi apply

# View pending changes
chezmoi diff

# Check status
chezmoi status

# Edit this repo in nvim
cd ~/.dotfiles && nvim .

# Force Neovim rebuild
rm ~/.local/state/chezmoi/neovim-build.txt && chezmoi apply
```

## Neovim

The Neovim config lives in
[dot_config/nvim](/Users/william/.dotfiles/dot_config/nvim).

Edit it from this repo like everything else:

After pulling Neovim changes, run:

```vim
:Lazy sync
```

LazyVim and spell state are tracked using chezmoi-managed symlinks so external
writes go back into the source tree instead of being overwritten on apply:

- [dot_config/nvim/symlink_lazy-lock.json.tmpl](.dotfiles/dot_config/nvim/symlink_lazy-lock.json.tmpl)
  -> `~/.config/nvim/lazy-lock.json` -> backing file:
  [dot_config/nvim/data/lazy-lock.json](.dotfiles/dot_config/nvim/data/lazy-lock.json)
- [dot_config/nvim/symlink_lazyvim.json.tmpl](.dotfiles/dot_config/nvim/symlink_lazyvim.json.tmpl)
  -> `~/.config/nvim/lazyvim.json` -> backing file:
  [dot_config/nvim/data/lazyvim.json](.dotfiles/dot_config/nvim/data/lazyvim.json)
- [dot_config/nvim/spell/symlink_en.utf-8.add.tmpl](.dotfiles/dot_config/nvim/spell/symlink_en.utf-8.add.tmpl)
  -> `~/.config/nvim/spell/en.utf-8.add` -> backing file:
  [dot_config/nvim/data/en.utf-8.add](.dotfiles/dot_config/nvim/data/en.utf-8.add)
- [dot_config/nvim/spell/symlink_en.utf-8.add.spl.tmpl](.dotfiles/dot_config/nvim/spell/symlink_en.utf-8.add.spl.tmpl)
  -> `~/.config/nvim/spell/en.utf-8.add.spl` -> backing file:
  [dot_config/nvim/data/en.utf-8.add.spl](.dotfiles/dot_config/nvim/data/en.utf-8.add.spl)
