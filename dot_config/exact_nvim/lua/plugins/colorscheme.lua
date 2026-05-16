---Catppuccin colorscheme configuration
--- https://github.com/catppuccin/nvim
return {
  {
    "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      integrations = {
        cmp = true,
        blink_cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        treesitter_context = true,
        notify = false,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
