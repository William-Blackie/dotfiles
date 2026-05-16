---@class ConformConfig
---Configuration for conform.nvim (formatting)
---@field formatters_by_ft table<string, string[]> Formatters mapped to filetypes

---@class ConformFormatterConfig
---@field command string Formatter executable command
---@field args? string[] Command-line arguments
---@field stdin? boolean Whether to use stdin

---Formatting with conform.nvim
---Note: LazyVim handles format_on_save automatically, don't set it here
---@type LazyPluginSpec
return {
  "stevearc/conform.nvim",
  ---@type ConformConfig
  opts = {
    ---Formatters by filetype
    ---Each filetype can have multiple formatters that run sequentially
    --- https://github.com/stevearc/conform.nvim#customizing-formatters
    formatters_by_ft = {
      ---Web technologies
      html = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },

      ---Data formats
      yaml = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      toml = { "taplo" },

      ---Go
      go = { "gofumpt" },

      ---Shell
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt_zsh" },

      ---Fish
      fish = { "fish_indent" },

      ---Tmux (treated as shell script)
      tmux = { "shfmt" },

      ---Git
      gitconfig = { "prettier" },
      gitignore = { "prettier" },

      ---Config files
      kitty = { "shfmt" },
      readline = {},
    },
    formatters = {
      shfmt_zsh = {
        command = "shfmt",
        args = { "-ln", "zsh", "-i", "2" },
        stdin = true,
      },
      taplo = {
        command = "taplo",
        args = { "format", "--option", "align_entries=true", 'indent_string="  "', "-" },
      },
    },

    -- NOTE: Do NOT set format_on_save here - LazyVim handles it automatically
  },
}
