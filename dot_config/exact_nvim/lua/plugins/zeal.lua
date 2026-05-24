return {
  {
    "paradoxical-dev/zeal.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    lazy = false,
    keys = {
      {
        "<leader>fd",
        function()
          require("zeal").search()
        end,
        desc = "Search Zeal docs",
      },
      {
        "<leader>K",
        function()
          local query = vim.fn.expand("<cword>")
          require("zeal").search_ft(query)
        end,
        desc = "Search Zeal docs by ft for current word",
      },
    },
    opts = {
      browser = "w3m",
      picker = {
        type = "snacks",
        snacks = {
          layout = "select",
        },
      },
      ft_map = {
        lua = { "lua_5.1" },
        js = { "javascript", "node" },
      },
    },
  },
}
