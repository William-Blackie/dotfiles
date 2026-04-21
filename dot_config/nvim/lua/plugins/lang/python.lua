---Python language support (extends lazyvim.plugins.extras.lang.python)
---LazyVim extra provides: ruff, basedpyright, debugpy, conform, lint
---This adds: ty LSP with Django-specific configuration
return {
  -- LSP: ty with Django settings
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ty = {
          cmd_env = {
            DJANGO_SETTINGS_MODULE = vim.env.DJANGO_SETTINGS_MODULE
              or "sites.admin.settings.prod",
          },
          settings = {
            environment = {
              typeshed = (function()
                local paths = {
                  os.getenv("TYPESHED_PATH"),
                  vim.fn.expand("~/.local/src/typeshed"),
                }
                for _, p in ipairs(paths) do
                  if p and p ~= "" and vim.fn.isdirectory(p) == 1 then
                    return p
                  end
                end
                return nil
              end)(),
            },
          },
        },
      },
      setup = {
        ty = function()
          Snacks.util.lsp.on({ name = "ty" }, function(_, _)
            local buf = vim.api.nvim_get_current_buf()
            vim.keymap.set("n", "gr", function()
              Snacks.picker.grep({ pattern = vim.fn.expand("<cword>") })
            end, { buffer = buf, desc = "References" })
            vim.keymap.set("n", "gI", function()
              Snacks.picker.grep({
                pattern = "class " .. vim.fn.expand("<cword>") .. "\\(",
              })
            end, { buffer = buf, desc = "Implementations" })
          end)
          return false
        end,
      },
    },
  },

  -- Mason: ty is not in LazyVim's default python extra
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "ty" },
    },
  },
}
