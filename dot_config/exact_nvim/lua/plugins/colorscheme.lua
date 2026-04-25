---Catppuccin colorscheme configuration
--- https://github.com/catppuccin/nvim
---@type LazyPluginSpec
return {
  {
    "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
