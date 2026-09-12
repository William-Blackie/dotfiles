---@class LintConfig
---Configuration for nvim-lint (linting)
---@field linters_by_ft table<string, string[]> Linters mapped to filetypes
---@field linters table<string, table> Custom linter configurations

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
      scss = { "stylelint" },
      markdown = { "markdownlint-cli2" },
    },
    -- LazyVim extension to easily override linter options
    -- or add custom linters.
    ---@type table<string,table>
    linters = {
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
