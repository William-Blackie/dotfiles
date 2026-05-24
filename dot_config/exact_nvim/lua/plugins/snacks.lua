-- https://github.com/folke/snacks.nvim
---@type LazyPluginSpec[]
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      statuscolumn = { enabled = true },
      image = { eabled = true },
      picker = {
        ui_select = true,
        sources = {
          explorer = {
            hidden = true,
          },
          files = {
            hidden = true,
          },
        },
      },
    },
    config = function(_, opts)
      local snacks = require("snacks")
      snacks.setup(opts)
      if snacks.config.input.enabled then
        vim.ui.input = snacks.input.input
      end
      if snacks.config.picker.ui_select then
        vim.ui.select = snacks.picker.select
      end
    end,
  },
}
