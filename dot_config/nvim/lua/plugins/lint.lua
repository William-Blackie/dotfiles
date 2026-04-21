---@class LintConfig
---Configuration for nvim-lint (linting)
---@field linters_by_ft table<string, string[]> Linters mapped to filetypes
---@field linters table<string, table> Custom linter configurations

---Linting with nvim-lint
---@type LazyPluginSpec
return {
  "mfussenegger/nvim-lint",
  ---@type LintConfig
  opts = {
    linters_by_ft = {
      -- Shell
      sh = { "shellcheck" },
      bash = { "shellcheck" },
      zsh = { "shellcheck" },
      tmux = { "shellcheck" },
    },
    linters = {
      -- Custom linter options can go here
      selene = {
        condition = function(ctx)
          return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
            ~= nil
        end,
      },
    },
  },
}
