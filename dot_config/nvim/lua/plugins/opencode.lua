---@class OpencodeConfig
---Configuration for opencode.nvim

---@class RenderMarkdownConfig
---@field anti_conceal { enabled: boolean }
---@field file_types string[]

---@type LazyPluginSpec
return {
  ---Opencode AI assistant integration
  ---@see https://github.com/sudo-tee/opencode.nvim
  "sudo-tee/opencode.nvim",
  config = function()
    require("opencode").setup({})
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      ---@type RenderMarkdownConfig
      opts = {
        anti_conceal = { enabled = false },
        file_types = { "markdown", "opencode_output" },
      },
      ft = { "markdown", "opencode_output" },
    },
    "hrsh7th/nvim-cmp",
    "folke/snacks.nvim",
  },
}
