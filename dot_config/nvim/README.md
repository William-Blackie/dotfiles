# Neovim

LazyVim-based config for this dotfiles repo.

## Shape

- `init.lua` loads the core config and an optional untracked `config.local`
- `lua/config/` holds editor defaults, keymaps, autocmds, and lazy bootstrap
- `lua/plugins/` only contains tracked overrides that are actually in use
- `lazyvim.json` enables the LazyVim extras this config relies on

## Rules

- keep one path per concern
- prefer LazyVim extras over custom plugin specs when the extra already does the job
- keep machine-specific or experimental overrides in `config.local`, not tracked files

## Current choices

- theme: Catppuccin Mocha
- completion AI: Copilot
- python LSP: ty, selected via `vim.g.lazyvim_python_lsp`
- picker: Snacks picker via LazyVim extra
