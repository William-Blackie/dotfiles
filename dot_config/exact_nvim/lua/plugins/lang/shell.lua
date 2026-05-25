---Shell scripting support (sh, bash, zsh, tmux, fish)
---Uses bash-language-server for bash/sh.
---Uses zsh -n for zsh diagnostics because shellcheck does not parse zsh.
---There is no mature zsh LSP; zsh uses Treesitter, formatting, lint, and
---generic blink.cmp sources.
---Chezmoi template composite filetypes are in lua/plugins/lang/chezmoi.lua
---@type LazyPluginSpec[]
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "zsh",
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        zsh = { "zsh" },
        ["zsh.chezmoitmpl"] = { "zsh" },
      },
    },
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.per_filetype = opts.sources.per_filetype or {}
      opts.sources.per_filetype.zsh = { inherit_defaults = true }
      opts.sources.per_filetype["zsh.chezmoitmpl"] = { inherit_defaults = true }
      return opts
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shfmt", "bash-language-server", "prettier" } },
  },
}
