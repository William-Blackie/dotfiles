-- Keep WhichKey responsible for its own prefix trigger. Do not map
-- <leader> to require("which-key").show(), which causes recursive loading.
return {
  {
    "folke/which-key.nvim",
    opts = {
      triggers = {
        { "<leader>", mode = { "n", "v" } },
        -- Wait for the rest of g-prefixed maps such as gai/gao instead of
        -- timing out into the built-in `ga` after timeoutlen.
        { "g", mode = "n" },
      },
    },
  },
}
