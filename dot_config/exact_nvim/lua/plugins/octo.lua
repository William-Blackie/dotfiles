---@class OctoConfig
---Configuration for octo.nvim (GitHub integration)
---@field picker string Picker to use
---@field enable_builtin boolean Enable built-in commands

---@type LazyPluginSpec
return {
  ---GitHub integration for Neovim
  ---@see https://github.com/pwntester/octo.nvim
  "pwntester/octo.nvim",
  cmd = "Octo",
  ---@type OctoConfig
  opts = { picker = "snacks", enable_builtin = true },
  keys = {
    { "<leader>o", group = "Octo" },
    { "<leader>oi", "<CMD>Octo issue list<CR>", desc = "Issues" },
    { "<leader>op", "<CMD>Octo pr list<CR>", desc = "PRs" },
    { "<leader>on", "<CMD>Octo notification list<CR>", desc = "Notifications" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "ibhagwan/fzf-lua",
    "nvim-tree/nvim-web-devicons",
  },
}
