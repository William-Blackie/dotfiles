-- Keep WhichKey responsible for its own prefix trigger. Do not map
-- <leader> to require("which-key").show(), which causes recursive loading.
return {
  {
    "folke/which-key.nvim",
    opts = {
      triggers = {
        { "<leader>", mode = { "n", "v" } },
      },
    },
  },
}
