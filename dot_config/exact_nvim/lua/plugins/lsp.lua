---LSP configuration
---Note: Language-specific settings are consolidated here from lang/*.lua files

---Django root markers
local python_root_markers = {
  "ty.toml",
  "pyproject.toml",
  "manage.py",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  ".git",
}

---@return string|nil
local function typeshed_path()
  local paths = {}
  local env_path = os.getenv("TYPESHED_PATH")
  if env_path and env_path ~= "" then
    paths[#paths + 1] = env_path
  end
  paths[#paths + 1] = vim.fn.expand("~/.local/src/typeshed")

  for _, path in ipairs(paths) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end
  return nil
end

---@return table
local function ty_settings()
  local settings = {}
  local typeshed = typeshed_path()
  if typeshed then
    settings.configuration = {
      environment = {
        typeshed = typeshed,
      },
    }
  end
  return settings
end

---@param bufnr number
---@param on_dir fun(root_dir: string)
local function django_root_dir(bufnr, on_dir)
  local root = vim.fs.root(bufnr, python_root_markers)
  if root then
    on_dir(root)
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jsonls = {
          settings = {
            json = {
              schemas = require("schemastore").json.schemas(),
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              runtime = {
                version = "LuaJIT",
              },
              diagnostics = {
                globals = { "vim" },
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
              },
            },
          },
        },

        bashls = {
          filetypes = { "sh", "bash", "sh.chezmoitmpl", "bash.chezmoitmpl" },
        },
        ty = {
          root_dir = django_root_dir,
          root_markers = python_root_markers,
          settings = {
            ty = ty_settings(),
          },
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
          filetypes = { "python" },
          root_dir = django_root_dir,
        },
        taplo = {
          keys = {
            {
              "K",
              function()
                if vim.bo.filetype == "toml" or vim.bo.filetype == "toml.chezmoitmpl" then
                  local win = vim.api.nvim_get_current_win()
                  local cursor = vim.api.nvim_win_get_cursor(win)
                  vim.lsp.buf.hover()
                  vim.api.nvim_win_set_cursor(win, cursor)
                end
              end,
              mode = "n",
              buffer = 0,
              desc = "Show hover (taplo)",
            },
          },
        },
      },
    },
  },
}
