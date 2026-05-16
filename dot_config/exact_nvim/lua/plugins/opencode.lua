---@class OpencodeConfig
---Configuration for opencode.nvim

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
      opts = {
        anti_conceal = { enabled = false },
        latex = { enabled = false },
        file_types = { "markdown", "opencode_output" },
      },
      ft = { "markdown", "opencode_output" },
    },
    "saghen/blink.cmp",
    "folke/snacks.nvim",
  },
}
