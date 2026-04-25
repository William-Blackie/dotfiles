# XDG Notes

## Issues fixed

- Root `.zshenv` now only bootstraps XDG and `ZDOTDIR`; the richer
  environment and PATH stay in `~/.config/zsh/lib/path.zsh`.
- zsh startup files use zsh shebangs, matching how they are sourced.
- Machine-local zsh files live under `~/.config/zsh`:
  - `~/.config/zsh/.zshenv.local`
  - `~/.config/zsh/.zprofile.local`
  - `~/.config/zsh/.zshrc.local`
  - `~/.config/zsh/.zshrc.d/*.zsh`
  - `~/.config/zsh/cheatsheet.local`
- tmux reloads from `$XDG_CONFIG_HOME/tmux/tmux.conf` and uses
  `$XDG_DATA_HOME/tmux/plugins`.
- tmux sets default XDG config/data env values itself, so plugin loading still
  works if the server starts outside zsh.
- `GNUPGHOME` is set to `$XDG_DATA_HOME/gnupg`.
- Cargo, Docker, Go, nvm, pyenv, AWS, and GnuPG data now live directly in XDG
  locations instead of using chezmoi-managed compatibility symlinks.

## Intentional compatibility choices

- `~/bin` remains in PATH for older personal scripts, after `~/.local/bin`.
- Git config still uses `~/.config/...` paths because Git config does not
  reliably expand `$XDG_CONFIG_HOME` in path values.
- The private work include remains `~/.dotfiles-work/zsh/*.zsh`; this is
  outside XDG by design so work-specific state stays separate from the main
  config tree.

## Edge cases to watch

- `XDG_RUNTIME_DIR` is synthesized under `${TMPDIR:-/tmp}/xdg-runtime-$UID` on
  macOS. It is best-effort, not a launchd-managed Linux-style runtime dir.
- Existing local zsh files were copied from `~/.*` to `~/.config/zsh`; the old
  files were left in place but are no longer sourced.
- Some tools still require environment variables to opt into XDG paths because
  their defaults are legacy home-directory paths.
- Homebrew is still macOS-focused and checks `/opt/homebrew` before `/usr/local`.
- Some third-party tools ignore XDG unless their own config supports it; keep
  those as documented exceptions instead of adding more shell glue.
