# Dotfiles

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/). The source
checkout is `~/dotfiles`. Chezmoi removes unmanaged entries directly inside
directories marked `exact_*` when applying them.

## Setup

Install Homebrew, then:

```sh
brew install chezmoi git
chezmoi init git@github.com:William-Blackie/dotfiles.git \
  --source ~/dotfiles \
  --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

On a configured Mac, pull `~/dotfiles` and run `chezmoi apply`. The apply
scripts install packages, fetch dependencies, and build Neovim and its provider
environments.

## Use

```sh
chezmoi diff
chezmoi apply
chezmoi status
```

Edit files in this repo, then apply. Changes made by an app need to be copied
back into the repo before they can be shared across Macs.

| Config         | Source                                        |
| -------------- | --------------------------------------------- |
| Shell          | `dot_config/zsh`                              |
| Neovim         | `dot_config/exact_nvim`                       |
| tmux           | `dot_config/exact_tmux/tmux.conf`             |
| Kitty          | `dot_config/exact_kitty/kitty.conf`           |
| AeroSpace      | `dot_config/exact_aerospace/aerospace.toml`   |
| Shortcut guide | `dot_hammerspoon/keyguide.lua`                |
| k9s            | `dot_config/private_k9s`                      |
| Vorssaint      | `dot_config/vorssaint/private_settings.plist` |

## Keyboard

| Shortcut                    | Action                             |
| --------------------------- | ---------------------------------- |
| `Command + Space`           | Vorssaint search                   |
| `Option + Space`, then `g`  | Search the complete shortcut guide |
| `Control + Space`, then `g` | tmux shortcut guide                |
| `Control + h/j/k/l`         | Neovim splits and tmux panes       |

AeroSpace uses `Option + Space` as a prefix: `h/j/k/l` focuses windows,
`y/u/i/o` moves them, `p/n` cycles workspaces, and `m` focuses the next monitor.
tmux uses `Control + Space`, with `Control + b` as a fallback. Other Option
bindings remain available to Neovim. The Voyager firmware is managed in
Oryx/Keymapp.

Vorssaint utilities use `Control + Option + Command` plus a key; see the guide.
AeroSpace handles window management and macOS handles app switching. The
keyboard setup script disables the macOS shortcuts that compete with the two
Space prefixes.

After applying:

```sh
aerospace reload-config
tmux source-file ~/.config/tmux/tmux.conf
```

## Vorssaint

The tracked plist is a native settings export. Chezmoi imports it when the
snapshot changes, restarting Vorssaint and saving the previous settings under
`~/.local/state/vorssaint/previous-settings.plist`. Each Mac needs a version
supporting `--import-settings`; permissions and Login Items approval are local.

To save changes from the app:

```sh
/Applications/Vorssaint.app/Contents/MacOS/Vorssaint --export-settings \
  ~/dotfiles/dot_config/vorssaint/private_settings.plist
git -C ~/dotfiles diff -- dot_config/vorssaint/private_settings.plist
chezmoi apply
```

Review exports for private snippets or launcher entries before committing them.
Clipboard history stays local, keeps up to 100 items for seven days, and
excludes password managers. Auto-quit excludes development apps and browsers.
Cleanup is scheduled for Monday at 09:00 local time and moves selected items to
Trash.

- [ ] Check whether
      [Vorssaint #497](https://github.com/vorssaint/vorssaint-utils/issues/497)
      has shipped automatic settings-file loading, then replace the import
      script.

## k9s

Uses Catppuccin Mocha. The theme is downloaded through `.chezmoiexternal.toml`.

| Shortcut  | Action                                   |
| --------- | ---------------------------------------- |
| `Shift-1` | Pods                                     |
| `Shift-2` | Deployments                              |
| `Shift-3` | Services                                 |
| `Shift-4` | Events                                   |
| `Shift-5` | Rollout status for the selected workload |
| `Shift-6` | Watch events for the selected resource   |

The plugins use the active context and selected namespace. Press `Control + c`
to return from the events stream; quit k9s with `:q`.

## Neovim

LazyVim lock/state files are symlinked into `dot_config/exact_nvim/data/lazy`.
Use `:Lazy sync` to update plugins. `Space g d` toggles Diffview; `q` closes it
without saving or discarding edits.

Project environments come from approved direnv `.envrc` files. Run
`direnv allow` after reviewing a project's configuration. Restart language
servers when their environment changes. Virtualenv selection remains explicit.

The local Django ORM plugin has its own
[usage notes](dot_config/exact_nvim/lua/django-orm-analyzer/README.md).

## SSH

Enable the 1Password SSH agent on each Mac. Agent accounts, keys, and
`~/.config/1Password/ssh/agent.toml` stay local. Optional SSH overrides go in
`~/.ssh/config.local`.

## Checks

```sh
pnpm install
make check
```

Focused checks: `make test-neovim`, `make test-python`, and
`make test-vorssaint`. Neovim checks require the installed plugins and Python
Tree-sitter parser.
