---Shell scripting support (sh, bash, zsh, tmux, fish)
---Note: shellcheck only supports sh/bash/dash/ksh, not zsh
---Uses bash-language-server for bash/sh and zsh
---Chezmoi template composite filetypes are in lua/plugins/lang/chezmoi.lua
return {
  -- Formatting
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
      },
    },
  },
  -- treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    ensure_installed = {
      "zsh",
    },
  },

  -- LSP: bash-language-server for bash/sh/zsh
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {
          filetypes = { "sh", "bash", "zsh" },
        },
      },
    },
  },

  -- Mason
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shfmt", "bash-language-server" } },
  },
}
