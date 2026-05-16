---LSP and completion configuration
---Note: Language-specific LSP servers are defined in lua/plugins/lang/*.lua
---@type LazyPluginSpec[]
return {
  -- Mason: Package manager for LSPs, DAPs, linters, and formatters
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- General LSPs
        "bash-language-server",
        "json-lsp",
        "lua-language-server",
        "marksman",
      },
    },
  },
  -- Core config-file LSPs. neoconf health still checks lspconfig's legacy
  -- manager registry, so these are set up through lspconfig directly.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jsonls = {},
        lua_ls = {},
      },
      setup = {
        jsonls = function(_, opts)
          require("lspconfig").jsonls.setup(opts)
          return true
        end,
        lua_ls = function(_, opts)
          require("lspconfig").lua_ls.setup(opts)
          return true
        end,
      },
    },
  },
  -- Tree-sitter parser required by neoconf for JSONC settings files.
  {
    "nvim-treesitter/nvim-treesitter",
    init = function()
      local json_parser = vim.api.nvim_get_runtime_file("parser/json.*", false)[1]
      if json_parser then
        pcall(vim.treesitter.language.add, "jsonc", {
          path = json_parser,
          symbol_name = "json",
        })
      end
    end,
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "json",
      })
    end,
  },
}
