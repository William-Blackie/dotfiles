-- blink.cmp
return {
  "saghen/blink.cmp",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "jdrupal-dev/css-vars.nvim",
    "alexandre-abrioux/blink-cmp-npm.nvim",
    "disrupted/blink-cmp-conventional-commits",
    "Kaiser-Yang/blink-cmp-git",
    "ribru17/blink-cmp-spell",
  },
  opts = {
    keymap = { preset = "default" },
    completion = { documentation = { auto_show = false } },

    -- (Default) list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      compat = { "conventional_commits" },
      default = {
        "lsp",
        "path",
        "snippets",
        "buffer",
        "spell",
      },
      per_filetype = {
        gitcommit = { "git", "conventional_commits", "buffer" },
        css = { "lsp", "path", "snippets", "buffer", "css_vars" },
        javascript = { "lsp", "path", "snippets", "buffer", "css_vars", "npm" },
        javascriptreact = { "lsp", "path", "snippets", "buffer", "css_vars", "npm" },
        typescript = { "lsp", "path", "snippets", "buffer", "css_vars", "npm" },
        typescriptreact = { "lsp", "path", "snippets", "buffer", "css_vars", "npm" },
      },
      providers = {
        css_vars = {
          name = "css-vars",
          module = "css-vars.blink",
          opts = {
            -- WARNING: The search is not optimized to look for variables in JS files.
            -- If you change the search_extensions you might get false positives and weird completion results.
            search_extensions = { ".js", ".ts", ".jsx", ".tsx" },
          },
        },
        npm = {
          name = "npm",
          module = "blink-cmp-npm",
          async = true,
          -- optional - make blink-cmp-npm completions top priority (see `:h blink.cmp`)
          score_offset = 100,
          -- optional - blink-cmp-npm config
          opts = {
            ignore = {},
            only_semantic_versions = true,
            only_latest_version = false,
          },
        },
        git = {
          module = "blink-cmp-git",
          name = "Git",
          opts = {
            -- options for the blink-cmp-git
          },
        },
        -- https://github.com/disrupted/blink-cmp-conventional-commits
        conventional_commits = {
          name = "Conventional Commits",
          module = "blink-cmp-conventional-commits",
          enabled = function()
            return vim.bo.filetype == "gitcommit"
          end,
          opts = {
            -- See Configuration section below for available options
          },
        },
        spell = {
          name = "Spell",
          module = "blink-cmp-spell",
          opts = {
            enable_in_contexts = { "markdown", "gitcommit", "python", "lua", "javascript", "typescript", "rust", "go" },
          },
        },
      },
    },
  },
}
