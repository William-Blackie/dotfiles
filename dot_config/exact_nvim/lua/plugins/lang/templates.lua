---Template engine support (Django, Jinja2)
---@type LazySpec
return {
  -- Formatting
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        htmldjango = { "prettier", "djlint" },
        jinja = { "djlint" },
        jinja2 = { "djlint" },
      },
    },
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        djlsp = {
          ---@return string[]
          cmd = function()
            local root = vim.fs.root(0, { "pyproject.toml", "manage.py", ".git" })
              or vim.fn.getcwd()
            local candidates = {
              root .. "/.venv/bin/djlsp",
              root .. "/django/.venv/bin/djlsp",
              vim.fn.exepath("djlsp"),
            }
            for _, c in ipairs(candidates) do
              if c and c ~= "" and vim.fn.executable(c) == 1 then
                return { c }
              end
            end
            return { "djlsp" }
          end,
          filetypes = { "htmldjango", "html", "jinja", "jinja2" },
          init_options = {
            django_settings_module = vim.env.DJANGO_SETTINGS_MODULE
              or "sites.app.settings.test",
          },
        },
      },
    },
  },

  -- Mason
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "djlint", "django-template-lsp" } },
  },
}
