---@class TmuxNavigationConfig
---Configuration for nvim-tmux-navigation
---@field disable_when_zoomed boolean Disable when tmux pane is zoomed

---@type LazyPluginSpec
return {
  ---Tmux navigation integration
  ---@see https://github.com/alexghergh/nvim-tmux-navigation
  "alexghergh/nvim-tmux-navigation",
  config = function()
    local nav = require("nvim-tmux-navigation")
    ---@type TmuxNavigationConfig
    nav.setup({ disable_when_zoomed = true })
    vim.keymap.set("n", "<C-h>", nav.NvimTmuxNavigateLeft)
    vim.keymap.set("n", "<C-j>", nav.NvimTmuxNavigateDown)
    vim.keymap.set("n", "<C-k>", nav.NvimTmuxNavigateUp)
    vim.keymap.set("n", "<C-l>", nav.NvimTmuxNavigateRight)
  end,
}
