-- https://github.com/folke/snacks.nvim
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            -- Override to show Git hidden files.
            hidden = true,
          },
          files = {
            hidden = true,
          },
        },
      },
    },
  },
}
