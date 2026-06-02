---@class LintConfig
---Configuration for nvim-lint (linting)
---@field linters_by_ft table<string, string[]> Linters mapped to filetypes
---@field linters table<string, table> Custom linter configurations

local python_root_markers = {
  "pyproject.toml",
  "ruff.toml",
  ".ruff.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "manage.py",
  ".git",
}

local function python_root()
  return vim.fs.root(0, python_root_markers) or vim.fn.getcwd()
end

local function project_executable(root, exe)
  local candidates = {
    root and (root .. "/.venv/bin/" .. exe) or nil,
    root and (root .. "/venv/bin/" .. exe) or nil,
    root and (root .. "/django/.venv/bin/" .. exe) or nil,
    vim.fn.exepath(exe),
    vim.fn.stdpath("data") .. "/mason/bin/" .. exe,
  }
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end
  return exe
end

---Linting with nvim-lint
---@type LazyPluginSpec
return {
  "mfussenegger/nvim-lint",
  event = "LazyFile",
  ---@type LintConfig
  opts = {
    -- Event to trigger linters
    events = { "BufWritePost", "BufReadPost", "InsertLeave" },
    linters_by_ft = {
      -- Shell
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      zsh = { "zsh" },
      ["zsh.chezmoitmpl"] = { "zsh" },
      python = { "ruff" },
      scss = { "stylelint" },
      markdown = { "markdownlint-cli2" },
    },
    -- LazyVim extension to easily override linter options
    -- or add custom linters.
    ---@type table<string,table>
    linters = {
      ruff = {
        cmd = function()
          return project_executable(python_root(), "ruff")
        end,
      },
      -- -- Example of using selene only when a selene.toml file is present
      -- selene = {
      --   -- `condition` is another LazyVim extension that allows you to
      --   -- dynamically enable/disable linters based on the context.
      --   condition = function(ctx)
      --     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
      --   end,
      -- },
    },
  },
}
