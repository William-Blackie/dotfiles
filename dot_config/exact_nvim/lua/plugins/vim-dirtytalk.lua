-- Programmer dictionary
-- https://github.com/psliwka/vim-dirtytalk
-- @type LazyPluginSpec
return {
  "benelan/vim-dirtytalk",
  build = ":DirtytalkUpdate",
  config = function()
    vim.opt.spelllang = { "en", "programming" }
  end,
}
