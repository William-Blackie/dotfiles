---@type LazyPluginSpec[]
return {
  {
    "xvzc/chezmoi.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      edit = { watch = true },
      events = {
        on_open = { notification = { enable = false } },
        on_watch = { notification = { enable = false } },
        on_apply = { notification = { enable = false } },
      },
    },
    keys = {
      {
        "<leader>cz",
        function()
          require("chezmoi.pick").snacks()
        end,
        desc = "Browse chezmoi files",
      },
      {
        "<leader>cza",
        function()
          require("chezmoi.commands").apply({})
        end,
        desc = "Chezmoi apply",
      },
    },
  },
  {
    "alker0/chezmoi.vim",
    init = function()
      vim.g["chezmoi#use_external"] = 1
    end,
  },
}
