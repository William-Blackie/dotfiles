---@type LazySpec
return {
  {
    "psliwka/vim-dirtytalk",
    -- Broken on Neovim 0.12; keep the spec ready for older/stable installs.
    enabled = vim.fn.has("nvim-0.12") == 0,
    event = "VeryLazy",
  },
}
