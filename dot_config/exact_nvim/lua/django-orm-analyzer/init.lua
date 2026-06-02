---@class DjangoORMConfig
---@field python_cmd string Path to python interpreter (local mode)
---@field docker_container? string Docker container name/id to exec into (overrides local python)
---@field docker_project_root? string Project root path inside the container (defaults to local project root)
---@field keymaps table Keymaps for quick analysis
---@field virtual_text table Virtual text options
---@field diagnostics table Diagnostics options
---@field window table Floating window options

---@class DjangoORMAnalyzer
---@field config DjangoORMConfig
local M = {}

M.config = {
  -- Path to python interpreter (local mode, ignored when docker_container is set)
  python_cmd = "python3",
  -- Docker container name or ID to run the analysis inside.
  -- When set, the plugin copies its Python files into the container
  -- via `docker cp` and executes via `docker exec` on every analysis.
  -- Example: docker_container = "my_web_container"
  docker_container = nil,
  -- Project root path inside the Docker container.
  -- Defaults to the locally-detected project root when nil.
  -- Example: docker_project_root = "/app"
  docker_project_root = nil,
  -- Keymaps for quick analysis
  keymaps = {
    analyze = "<leader>oa", -- Analyze current query (visual selection or current line)
  },
  -- Virtual text options
  virtual_text = {
    enabled = true,
    prefix = " ➔ ",
  },
  -- Diagnostics options
  diagnostics = {
    enabled = true,
  },
  -- Floating window options
  window = {
    border = "rounded", -- "single", "double", "rounded", "solid", "shadow"
    width = 0.75, -- percentage of editor width
    height = 0.7, -- percentage of editor height
  },
}

-- Initialize default highlight groups for a premium developer experience
local function setup_highlights()
  local colors = {
    primary = "#6366f1", -- Indigo
    success = "#10b981", -- Emerald
    warning = "#f59e0b", -- Amber
    danger = "#f43f5e", -- Rose
    bg_card = "#1e1e2e", -- Dark Slate
    text_muted = "#7f849c",
  }

  local hl_groups = {
    DjangoORMTitle = { fg = colors.primary, bold = true },
    DjangoORMHeader = { fg = colors.text_muted, bold = true, underline = true },
    DjangoORMSQL = { fg = "#89b4fa" },
    DjangoORMOptimal = { fg = colors.success, bold = true },
    DjangoORMWarning = { fg = colors.warning, bold = true },
    DjangoORMCritical = { fg = colors.danger, bold = true },
    DjangoORMVirtualTextOpt = { fg = "#585b70", italic = true },
    DjangoORMVirtualTextWarn = { fg = colors.warning, italic = true },
    DjangoORMVirtualTextCrit = { fg = colors.danger, italic = true },
    DjangoORMBorder = { fg = colors.primary },
    DjangoORMBg = { bg = colors.bg_card },
  }

  for name, hl in pairs(hl_groups) do
    vim.api.nvim_set_hl(0, name, hl)
  end
end

---Initialize the Django ORM Analyzer plugin with optional user settings.
---@param opts? table User-defined options to override default settings
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_highlights()

  -- Automatically register default keymaps if defined
  if M.config.keymaps.analyze then
    vim.keymap.set({ "n", "v" }, M.config.keymaps.analyze, function()
      M.analyze()
    end, { desc = "Django ORM Analyze Query" })
  end

  -- Register User Command dynamically on setup
  vim.api.nvim_create_user_command("DjangoORMAnalyze", function()
    M.analyze()
  end, {
    range = true,
    desc = "Analyze highlighted Django ORM query for time and space complexity",
  })
end

---Trigger the visual query selection and run complexity analysis.
function M.analyze()
  local core = require("django-orm-analyzer.core")
  core.analyze_query()
end

return M
