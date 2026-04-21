---Chezmoi dotfiles support
---Complements lazyvim.plugins.extras.util.chezmoi
---LazyVim extra provides: chezmoi.vim, chezmoi.nvim picker, dashboard
---This adds: filetype detection, LSP, linting, formatting for chezmoi source files
---@type LazyPluginSpec
return {
  -- Filetype detection for chezmoi scripts and config files
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      vim.filetype.add({
        pattern = {
          -- Chezmoi scripts by shebang
          [".chezmoiscripts/.*"] = function(path, buf)
            local shebang = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
            if
              shebang:match("^#!.*/bin/zsh") or shebang:match("^#!.*/usr/bin/env zsh")
            then
              return "zsh"
            elseif
              shebang:match("^#!.*/bin/bash") or shebang:match("^#!.*/usr/bin/env bash")
            then
              return "bash"
            elseif shebang:match("^#!.*/bin/sh") then
              return "sh"
            end
          end,
          -- Config files with explicit types
          ["dot_config/kitty/.*%.conf"] = "kitty",
          ["dot_config/tmux/.*%.conf"] = "tmux",
          ["dot_config/readline/.*"] = "readline",
          ["dot_zshrc"] = "zsh",
          [".zshrc"] = "zsh",
          [".zshenv"] = "zsh",
          ["dot_zshenv"] = "zsh",
          [".chezmoiignore"] = "gitignore",
          [".ignore"] = "gitignore",
          ["%.env"] = "sh",
          ["%.env%..*"] = "sh",
          [".nvmrc"] = "sh",
          ["dot_nvmrc"] = "sh",
        },
        filename = {
          [".chezmoiignore"] = "gitignore",
          ["dot_zshrc"] = "zsh",
          ["dot_zshenv"] = "zsh",
          ["dot_nvmrc"] = "sh",
        },
      })
      return opts
    end,
  },

  -- LSP: bash-language-server for shell scripts + chezmoi template composites
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {
          filetypes = {
            "sh",
            "bash",
            "zsh",
            "sh.chezmoitmpl",
            "bash.chezmoitmpl",
            "zsh.chezmoitmpl",
          },
        },
        taplo = {
          keys = {
            {
              "K",
              function()
                if vim.bo.filetype == "toml" or vim.bo.filetype == "toml.chezmoitmpl" then
                  local win = vim.api.nvim_get_current_win()
                  local cursor = vim.api.nvim_win_get_cursor(win)
                  vim.lsp.buf.hover()
                  vim.api.nvim_win_set_cursor(win, cursor)
                end
              end,
              mode = "n",
              buffer = 0,
              desc = "Show hover (taplo)",
            },
          },
        },
      },
    },
  },

  -- Formatting
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        ["sh.chezmoitmpl"] = { "shfmt" },
        ["bash.chezmoitmpl"] = { "shfmt" },
        ["yaml.chezmoitmpl"] = { "prettier" },
        ["json.chezmoitmpl"] = { "prettier" },
        ["jsonc.chezmoitmpl"] = { "prettier" },
        ["toml.chezmoitmpl"] = { "taplo" },
        ["css.chezmoitmpl"] = { "prettier" },
        ["html.chezmoitmpl"] = { "prettier" },
        ["gitconfig.chezmoitmpl"] = { "prettier" },
        ["conf.chezmoitmpl"] = {},
        ["kitty"] = { "shfmt" },
        ["tmux"] = { "shfmt" },
        ["readline"] = {},
      },
    },
  },

  -- Linting
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        ["sh.chezmoitmpl"] = { "shellcheck" },
        ["bash.chezmoitmpl"] = { "shellcheck" },
        ["tmux.chezmoitmpl"] = { "shellcheck" },
        tmux = { "shellcheck" },
      },
    },
  },

  -- Treesitter for config file syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "gitignore",
        "properties",
      })
    end,
  },

  -- Mason
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shfmt", "bash-language-server", "shellcheck" } },
  },
}
