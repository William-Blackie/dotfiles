# Dotfiles

MacOS-first dotfiles managed by [chezmoi](https://www.chezmoi.io/).

The chezmoi source directory is `~/dotfiles`. Most config lives under
`dot_config/exact_*`, which means chezmoi treats those directories as the full
desired state and removes unmanaged files inside them on apply.

## New Machine

Install Homebrew, then run:

```sh
brew install chezmoi git
chezmoi init git@github.com:William-Blackie/dotfiles.git \
  --source ~/dotfiles \
  --config-path ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

On a second machine where the repo already exists:

```sh
chezmoi init --source ~/dotfiles \
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

Edit files in `~/dotfiles`, then apply. If a tool writes useful config back into
`$HOME`, copy or add it back into `~/dotfiles` so the repo stays the source of
truth.

## k9s

k9s uses Catppuccin Mocha, matching the other terminal tools. Its config is
managed under `dot_config/private_k9s`, and `.chezmoiexternal.toml` installs all
[Catppuccin skins](https://github.com/catppuccin/k9s) into
`~/.config/k9s/skins`. The shell's `XDG_CONFIG_HOME` setting makes k9s use this
path on macOS too.

Change `k9s.ui.skin` in `dot_config/private_k9s/private_config.yaml.tmpl` to
select another flavor, then run `chezmoi apply ~/.config/k9s` and restart k9s.
Theme downloads refresh weekly on apply, or immediately with
`chezmoi apply --refresh-externals ~/.config/k9s`.

Logs start with 500 lines, retain up to 10,000, wrap long lines, and show
timestamps. The logo and splash screen are hidden. Quit with `:q`; `Ctrl-c` does
not exit k9s.

Aliases, navigation hotkeys, and plugins are also managed in
`dot_config/private_k9s`:

| Shortcut  | Action                                                     |
| --------- | ---------------------------------------------------------- |
| `Shift-1` | Pods                                                       |
| `Shift-2` | Deployments                                                |
| `Shift-3` | Services                                                   |
| `Shift-4` | Events                                                     |
| `Shift-5` | Rollout status for a Deployment, StatefulSet, or DaemonSet |
| `Shift-6` | Watch events for the selected resource                     |

These are the `!`, `@`, `#`, `$`, `%`, and `^` keys on a US layout. Both plugins
use the selected resource's namespace, the active k9s context, and its
kubeconfig. Rollout status appears in the k9s message area without waiting for
completion. Resource events stream in the terminal; press `Ctrl-c` to return to
k9s. The plugins use the already-managed `kubectl`.

## Keyboard And Windowing

The ZSA Voyager layout is managed in Keymapp/Oryx, not in these dotfiles. Keep
the keyboard firmware aligned with this modifier contract:

- `Ctrl + h/j/k/l` navigates Neovim splits and tmux panes.
- `Command + Space` opens Vorssaint's Command Bar. Chezmoi enables this shortcut
  and disables Spotlight's competing binding. Vorssaint's launch-at-login
  preference is included; macOS may require enabling it in Login Items on a new
  machine.
- Bare `Alt` bindings, except `Option + Space`, belong to Neovim and its
  plugins.
- `Option + Space` enters a one-shot AeroSpace prefix mode on either keyboard,
  mirroring tmux's `Control + Space`.
- After the prefix, `h/j/k/l` focuses windows and `y/u/i/o` moves them.
- After the prefix, `p/n` cycles workspaces and `m` focuses the next monitor.
- After the prefix, `g` opens the searchable system-wide key guide.
- tmux uses `Control + Space` as the primary prefix, with `Control + b` kept as
  a fallback. Press `g` after the prefix to open its guide.
- The menu-bar keyboard icon opens the complete guide from any app.

The proposed Oryx layout is documented in
[`docs/zsa-voyager-oryx-layout.md`](docs/zsa-voyager-oryx-layout.md).

The shortcut guide is managed in `dot_hammerspoon/keyguide.lua`.

Vorssaint utilities use `Control + Option + Command` plus a key. Common keys are
`V` for clipboard history, `D` for shelf, `S` for sound output, `M` for mic
mute, `K` for keep awake, `N` for notes, `L` for snippets, `T` for OCR, `C` for
color picker, `W` for camera preview, and `Q` for the quick panel. Add `Shift`
to `V` to paste plain text. `3/4/5` open full-screen capture, region capture,
and recording; `H/E/P` open recent captures, the last capture, and a clipboard
image in the editor. The complete guide lists brightness and other controls.

AeroSpace owns window layouts, floating, fullscreen, and monitor focus. macOS
owns app switching and standard screenshot keys. Vorssaint's window layout,
maximizer, app switcher, focus-following, and modifier remapping are disabled.
The keyboard setup script reserves macOS's `Control + Space` for tmux and
`Command + Space` for Vorssaint without changing other system shortcuts.

Useful reload commands:

```sh
chezmoi apply
aerospace reload-config
tmux source-file ~/.config/tmux/tmux.conf
```

- [ ] Check whether changes for
      [Vorssaint #497: Store settings in a folder](https://github.com/vorssaint/vorssaint-utils/issues/497)
      have been merged and released. If supported, use automatic settings-file
      loading in place of the backup import script.

## Vorssaint Across Macs

`dot_config/vorssaint/private_settings.plist` is a complete portable settings
backup exported by Vorssaint 3.4.3. It includes feature choices, shortcuts,
appearance, and the launch-at-login preference. The native exporter includes
default values too, so another Mac receives the same setup.

Chezmoi installs it at `~/.config/vorssaint/settings.plist`. When the backup
changes,
`.chezmoiscripts/run_onchange_after_20-import-vorssaint-settings.sh.tmpl` uses
Vorssaint's native `--import-settings` command. It saves the previous settings
at `~/.local/state/vorssaint/previous-settings.plist`, closes a running
Vorssaint, imports, and starts it. Unchanged backups are not reimported on every
apply. Each Mac needs a version of Vorssaint supporting these backup commands;
macOS permissions and Login Items approval are configured on each device.

To carry later changes from the app back into the repo:

```sh
/Applications/Vorssaint.app/Contents/MacOS/Vorssaint --export-settings \
  ~/dotfiles/dot_config/vorssaint/private_settings.plist
git -C ~/dotfiles diff -- dot_config/vorssaint/private_settings.plist
chezmoi apply
```

Review exports before committing: settings backups can include text snippets and
custom launcher entries. Vorssaint excludes clipboard history, shelf contents,
usage history, and machine state from its portable backup. On another Mac, pull
the repo and run `chezmoi apply` to restore this setup.

Clipboard history keeps up to 100 items for seven days, filters sensitive text,
and excludes password managers. Clipboard contents stay on each Mac. Auto-quit
is enabled with exceptions for terminals, VS Code, Codex, browsers, and
1Password. Weekly cleanup runs Monday at 09:00 local time with a completion
notification; Vorssaint's scheduled cleaner moves its safe selection to Trash.
Display brightness uses the utility modifier layer; add Shift for keyboard
brightness. Native brightness keys keep their usual behavior. Audio device
priority discovers the devices attached to each Mac; device IDs and their order
can differ across machines.

Run `make test-vorssaint` to check active shortcut collisions, modifier
ownership, clipboard exclusions, and app-quitting exceptions before applying.

## 1Password And SSH

SSH is wired to the 1Password SSH agent through `dot_ssh/config.tmpl`. The repo
only stores the generic socket path.

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
`dot_config/exact_nvim/data/lazy`, so normal Lazy writes are preserved.

Useful commands:

```sh
nvim
# then inside nvim:
# :Lazy sync
```

Press `<leader>gd` to open working changes in Diffview, or close the current
Diffview. Press `q` in a diff or history pane, or `<leader>gq`, to close it.
Unsaved edits stay in memory; closing Diffview does not save or discard them.

Project environments come from direnv's approved `.envrc` files. Neovim imports
`direnv export json` before plugin setup and when entering files or changing
directories; direnv restores the previous environment when leaving a project.
Run `direnv allow` in the project after reviewing changes to its `.envrc`.
Neovim sets `NVIM_DIRENV=1` only for direnv evaluation, allowing projects to
specify editor-only overrides. Virtualenv selection remains explicit. Restart
existing language servers after changing environments if they need the new
variables. Project CSS paths follow each buffer's Git root.

Run `make check` for formatting, linting, and focused Neovim regression checks,
or `make test-neovim` for just the regression checks. These require Neovim, its
Python Tree-sitter parser, direnv, and the installed `nvim-html-css`,
`lazy.nvim`, `LazyVim`, and `snacks.nvim` plugins. Checks use temporary files
and do not apply the dotfiles.
