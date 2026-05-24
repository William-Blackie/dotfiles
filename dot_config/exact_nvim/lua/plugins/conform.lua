---@class ConformConfig
---@field formatters_by_ft table<string, string[]> Formatters mapped to filetypes
---@class ConformFormatterConfig
---@field command string|fun(ctx: table):string Formatter executable
---@field args? string[] Command-line arguments
---@field stdin? boolean Whether to use stdin
---@field cwd? fun(self: table, ctx: table):string|nil Working directory
---@field prepend_args? string[] Args to prepend to command

---Helper to find project-local executable
---@param root string|nil
---@param exe string
---@return string
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

---Django template root markers
local django_template_root_markers =
  { ".djlintrc", "pyproject.toml", "setup.cfg", "tox.ini", "manage.py", ".git" }
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

local function python_root(ctx)
  return vim.fs.root(ctx.filename, python_root_markers)
end

local function python_project_executable(exe)
  return function(_, ctx)
    return project_executable(python_root(ctx), exe)
  end
end

return {
  "stevearc/conform.nvim",
  opts = {
    log_level = vim.log.levels.DEBUG,
    formatters_by_ft = {
      html = { "prettier" },
      htmldjango = { "djlint" },
      css = { "prettier" },
      scss = { "prettier" },
      yaml = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      toml = { "taplo" },
      go = { "gofumpt" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt_zsh" },
      fish = { "fish_indent" },
      tmux = { "shfmt" },
      gitconfig = { "prettier" },
      gitignore = { "prettier" },
      kitty = { "shfmt" },
      readline = {},
      python = { "ruff_fix", "ruff_organize_imports", "ruff_format", "docformatter" },
      ["sh.chezmoitmpl"] = { "shfmt" },
      ["bash.chezmoitmpl"] = { "shfmt" },
      ["zsh.chezmoitmpl"] = { "shfmt_zsh" },
      ["yaml.chezmoitmpl"] = { "prettier" },
      ["json.chezmoitmpl"] = { "prettier" },
      ["jsonc.chezmoitmpl"] = { "prettier" },
      ["toml.chezmoitmpl"] = { "taplo" },
      ["css.chezmoitmpl"] = { "prettier" },
      ["html.chezmoitmpl"] = { "prettier" },
      ["gitconfig.chezmoitmpl"] = { "prettier" },
      ["conf.chezmoitmpl"] = {},
    },
    formatters = {
      shfmt_zsh = {
        command = "shfmt",
        args = { "-ln", "zsh", "-i", "2" },
        stdin = true,
      },
      taplo = {
        command = "taplo",
        args = { "format", "--option", "align_entries=true", 'indent_string="  "', "-" },
      },
      djlint = {
        command = function(_, ctx)
          return project_executable(
            vim.fs.root(ctx.filename, django_template_root_markers),
            "djlint"
          )
        end,
        cwd = function(_, ctx)
          return vim.fs.root(ctx.filename, django_template_root_markers)
        end,
        prepend_args = { "--profile=django" },
      },
      ruff_fix = {
        command = python_project_executable("ruff"),
        cwd = function(_, ctx)
          return python_root(ctx)
        end,
      },
      ruff_organize_imports = {
        command = python_project_executable("ruff"),
        cwd = function(_, ctx)
          return python_root(ctx)
        end,
      },
      ruff_format = {
        command = python_project_executable("ruff"),
        cwd = function(_, ctx)
          return python_root(ctx)
        end,
      },
    },
  },
}
