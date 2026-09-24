-- blink.cmp
---@type LazyPluginSpec
return {
  "saghen/blink.cmp",
  -- Pin to a tagged release so lazy.nvim always lands on a git tag: the fuzzy
  -- matcher then downloads a prebuilt binary from GitHub releases instead of
  -- falling back to `cargo build --release` (which fails here - ~/.cargo is
  -- owned by root, see the cargo permission note).
  version = "v1.*",
  dependencies = {
    "saghen/blink.compat",
    "rafamadriz/friendly-snippets",
    "alexandre-abrioux/blink-cmp-npm.nvim",
    "disrupted/blink-cmp-conventional-commits",
    "Jezda1337/nvim-html-css",
    "Kaiser-Yang/blink-cmp-git",
    "ribru17/blink-cmp-spell",
    "moyiz/blink-emoji.nvim",
    {
      "jdrupal-dev/css-vars.nvim",
    },
    {
      "ph1losof/ecolog.nvim",
      branch = "v1",
      opts = {
        integrations = {
          nvim_cmp = false,
          blink_cmp = true,
        },
      },
    },
  },
  opts = {
    -- Blink installs CursorMoved listeners globally. Keep them inert while
    -- navigating buffers; completion only needs to run in insert/select mode.
    enabled = function()
      return vim.api.nvim_get_mode().mode:match("^[is]") ~= nil
    end,
    -- Do not attach Blink to `/` or `?` searches (or `:` commands). This keeps
    -- its buffer source and command-line keymaps out of search navigation.
    cmdline = { enabled = false },
    keymap = { preset = "default" },
    completion = {
      trigger = {
        prefetch_on_insert = false,
        show_on_insert = false,
        show_on_insert_on_trigger_character = false,
      },
      documentation = {
        -- Resolve docs on demand with Ctrl-Space instead of while moving
        -- through completion candidates.
        auto_show = false,
        auto_show_delay_ms = 500,
        update_delay_ms = 500,
        window = {
          max_width = math.min(80, vim.o.columns),
          border = "rounded",
        },
      },
    },

    -- (Default) list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "ecolog" },
      per_filetype = {
        gitcommit = { inherit_defaults = true, "git", "conventional_commits", "emoji" },
        markdown = { inherit_defaults = true, "emoji" },
        css = { inherit_defaults = true, "css_vars" },
        javascript = { inherit_defaults = true, "css_vars", "npm" },
        javascriptreact = { inherit_defaults = true, "css_vars", "npm" },
        typescript = { inherit_defaults = true, "css_vars", "npm" },
        typescriptreact = { inherit_defaults = true, "css_vars", "npm" },
      },
      providers = {
        ecolog = {
          name = "ecolog",
          module = "ecolog.integrations.cmp.blink_cmp",
        },
        emoji = {
          name = "Emoji",
          module = "blink-emoji",
          score_offset = 15,
          opts = {
            insert = true,
            trigger = function()
              return { ":" }
            end,
          },
          should_show_items = function()
            return vim.tbl_contains({ "gitcommit", "markdown" }, vim.o.filetype)
          end,
        },
        css_vars = {
          name = "css-vars",
          -- css-vars.nvim's own blink integration (css-vars.blink) requires
          -- "blink.lib.task", which doesn't exist in current blink.cmp
          -- (moved under "blink.cmp.lib.*") - it's broken upstream as of
          -- their HEAD too, not just our pinned version. Use our own
          -- self-contained source module instead.
          module = "config.sources.css_vars",

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
      },
    },
  },
}
