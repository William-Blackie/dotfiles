---Django language support
---@type LazySpec
local django_root_markers = { "manage.py", "pyproject.toml", ".git" }
local django_template_root_markers =
  { ".djlintrc", "pyproject.toml", "setup.cfg", "tox.ini", "manage.py", ".git" }

---@param dir string|nil
---@return boolean
local function is_templates_dir(dir)
  return dir ~= nil
    and (
      dir:match("^templates$")
      or dir:match("^templates/")
      or dir:match("/templates$")
      or dir:match("/templates/")
    )
end

vim.filetype.add({
  extension = {
    html = function(path, _)
      local dir = vim.fs.dirname(path)
      if is_templates_dir(dir) and vim.fs.root(path, django_root_markers) then
        return "htmldjango"
      end
      return "html"
    end,
  },
})

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

---@param bufnr number
---@param on_dir fun(root_dir: string)
local function django_root_dir(bufnr, on_dir)
  local root = vim.fs.root(bufnr, django_root_markers)
  if root then
    on_dir(root)
  end
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.htmldjango = { "djlint" }

      opts.formatters = opts.formatters or {}
      opts.formatters.djlint = {
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
      }
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ty = {
          cmd_env = {
            DJANGO_SETTINGS_MODULE = vim.env.DJANGO_SETTINGS_MODULE
              or "sites.admin.settings.prod",
          },
        },
        djlsp = {
          filetypes = { "htmldjango" },
          root_dir = django_root_dir,
          init_options = {
            django_settings_module = vim.env.DJANGO_SETTINGS_MODULE
              or "sites.admin.settings.prod",
          },
        },
        djls = {
          -- djlsp owns Django templates; djls adds Django-aware Python support.
          filetypes = { "python" },
          root_dir = django_root_dir,
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "djlint",
        "django-language-server",
        "django-template-lsp",
        "ty",
      },
    },
  },
}
