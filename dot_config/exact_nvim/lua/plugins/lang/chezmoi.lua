---Chezmoi dotfiles support
---Complements lazyvim.plugins.extras.util.chezmoi
---LazyVim extra provides: chezmoi.vim, chezmoi.nvim picker, dashboard
---This adds: filetype detection, LSP, linting, formatting for chezmoi source files
---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      vim.filetype.add({
        pattern = {
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
          ["dot_configs/kitty/.*%.conf"] = "kitty",
          ["dot_configs/tmux/.*%.conf"] = "tmux",
          ["dot_configs/readline/.*"] = "readline",
          ["dot_zshrc"] = "zsh",
          [".zshrc"] = "zsh",
          [".zshenv"] = "zsh",
          [".zprofile"] = "zsh",
          ["dot_zshenv"] = "zsh",
          ["dot_zprofile"] = "zsh",
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
          ["dot_zprofile"] = "zsh",
          ["dot_nvmrc"] = "sh",
        },
      })
      return opts
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        ["sh.chezmoitmpl"] = { "shellcheck" },
        ["bash.chezmoitmpl"] = { "shellcheck" },
        ["zsh.chezmoitmpl"] = { "zsh" },
        ["tmux.chezmoitmpl"] = { "shellcheck" },
        tmux = { "shellcheck" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "gitignore",
        "properties",
      })
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "shfmt", "bash-language-server", "shellcheck" } },
  },
}
