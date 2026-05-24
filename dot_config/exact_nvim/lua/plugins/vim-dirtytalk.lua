-- Programmer dictionary
-- https://github.com/psliwka/vim-dirtytalk
-- TODO: Move to original once merged for 0.12
---@type LazyPluginSpec
return {
  "sak96/vim-dirtytalk", -- psliwka/vim-dirtytalk
  commit = "88f7423b0627bbe37fb434ef9c71dd7fe41cc5b5",
  build = ":DirtytalkUpdate",
  config = function()
    vim.opt.spelllang = { "en", "programming" }
  end,
}
