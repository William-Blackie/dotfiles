---@class ObsidianWorkspace
---Obsidian workspace configuration
---@field name string Workspace name
---@field path string Workspace path

---@class ObsidianConfig
---Configuration for obsidian.nvim
---@field legacy_commands boolean Use legacy commands
---@field picker { name: string } Picker configuration
---@field workspaces ObsidianWorkspace[] List of workspaces

---@type LazyPluginSpec
return {
  ---Obsidian integration for Neovim
  ---@see https://github.com/obsidian-nvim/obsidian.nvim
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  cmd = "Obsidian",
  ft = "markdown",
  keys = {
    { "<leader>n", group = "Notes" },
    { "<leader>nn", "<CMD>Obsidian quick_switch<CR>", desc = "Quick Switch" },
    { "<leader>nf", "<CMD>Obsidian search<CR>", desc = "Search" },
    { "<leader>nd", "<CMD>Obsidian today<CR>", desc = "Daily Note" },
    { "<leader>nb", "<CMD>Obsidian backlinks<CR>", desc = "Backlinks" },
    { "<leader>no", "<CMD>Obsidian open<CR>", desc = "Open in Obsidian" },
  },
  ---@type ObsidianConfig
  opts = {
    legacy_commands = false,
    picker = { name = "fzf-lua" },
    workspaces = (function()
      local workspaces = {
        { name = "notes", path = vim.env.OBSIDIAN_NOTES_PATH or "~/Obsidian" },
        {
          name = "personal",
          path = vim.env.OBSIDIAN_PERSONAL_PATH or "~/Obsidian/Personal",
        },
      }
      -- Add work workspace if configured
      if vim.env.OBSIDIAN_WORK_PATH then
        table.insert(workspaces, { name = "work", path = vim.env.OBSIDIAN_WORK_PATH })
      end
      return workspaces
    end)(),
  },
  {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- or if using mini.icons/mini.nvim
    -- dependencies = { "nvim-mini/mini.icons" },
    ---@module "fzf-lua"
    ---@type fzf-lua.Config|{}
    ---@diagnostic disable: missing-fields
    opts = {},
    ---@diagnostic enable: missing-fields
  },
}
