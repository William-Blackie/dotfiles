---@class NotionConfig
---Configuration for notion.nvim

---@type LazyPluginSpec
return {
  ---Notion integration for Neovim
  ---@see https://github.com/Al0den/notion.nvim
  "Al0den/notion.nvim",
  lazy = false,
  dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  config = function()
    require("notion").setup()
  end,
}
