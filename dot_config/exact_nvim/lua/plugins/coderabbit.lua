-- https://github.com/smnatale/coderabbit.nvim
return {
  "smnatale/coderabbit.nvim",
  opts = {
    cli = {
      binary = "cr",
      timeout = 0,
      extra_args = {},
    },
    review = {
      type = "all", -- "all", "committed", or "uncommitted"
      base = nil,
      base_commit = nil,
    },
    diagnostics = {
      enabled = true,
      severity_map = {
        critical = vim.diagnostic.severity.ERROR,
        major = vim.diagnostic.severity.WARN,
        minor = vim.diagnostic.severity.INFO,
      },
      virtual_text = true,
      signs = true,
      underline = true,
    },
    show = {
      layout = "float", -- "float" or "buffer"
      float = {
        width = 0.6,
        height = 0.7,
        border = "rounded",
      },
    },
    quickfix = {
      auto = false, -- populate on review complete
    },
    history = {
      max_entries = 50, -- keep the most recent saved reviews per repo
    },
    on_review_complete = nil,
  },
}
