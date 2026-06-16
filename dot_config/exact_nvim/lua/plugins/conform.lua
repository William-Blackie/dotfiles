-- https://www.lazyvim.org/plugins/formatting
return {

  "stevearc/conform.nvim",
  dependencies = { "mason.nvim" },
  opts = {
    log_level = vim.log.levels.DEBUG,
    formatters_by_ft = {
      lua = { "stylua" },
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
      gitconfig = { "prettier" },
      gitignore = { "prettier" },
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
      ["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
      ["markdown"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
    },
    ---@type table<string, conform.FormatterConfigOverride|fun(bufnr: integer): nil|conform.FormatterConfigOverride>
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
      ["markdown-toc"] = {
        condition = function(_, ctx)
          for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
            if line:find("<!%-%- toc %-%->") then
              return true
            end
          end
        end,
      },
      ["markdownlint-cli2"] = {
        condition = function(_, ctx)
          local diag = vim.tbl_filter(function(d)
            return d.source == "markdownlint"
          end, vim.diagnostic.get(ctx.buf))
          return #diag > 0
        end,
      },
    },
  },
}
