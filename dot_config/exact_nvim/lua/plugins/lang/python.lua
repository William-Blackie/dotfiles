---Python language support
---@type LazySpec
return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        python = { "ruff_fix", "ruff_format" },
      },
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ty = {
          settings = {
            environment = {
              typeshed = (function()
                local paths = {
                  os.getenv("TYPESHED_PATH"),
                  vim.fn.expand("~/.local/src/typeshed"),
                }
                for _, path in ipairs(paths) do
                  if path and path ~= "" and vim.fn.isdirectory(path) == 1 then
                    return path
                  end
                end
                return nil
              end)(),
            },
          },
        },
        setup = {
          ty = function()
            Snacks.util.lsp.on({ name = "ty" }, function()
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
  },

  {
    "jeangiraldoo/codedocs.nvim",
    opts = {
      languages = {
        python = {
          default_style = "Google",
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "ruff" } },
  },
}
