-- https://github.com/Jezda1337/nvim-html-css
return {
  {
    "Jezda1337/nvim-html-css",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "saghen/blink.cmp",
    },
    opts = {
      enable_on = {
        "html",
        "htmldjango",
        "tsx",
        "jsx",
        "templ",
      },
      handlers = {
        definition = {
          bind = "gd",
        },
        hover = {
          bind = "K",
          wrap = true,
          border = "none",
          position = "cursor",
        },
      },
      documentation = {
        auto_show = true,
      },
      peek = {
        enabled = true,
        border = "rounded",
        position = "center",
        width = 0.5,
        height = 0.5,
        focus = true,
        style = "minimal",
      },
      style_sheets = (function()
        local sheets = {} -- Add URL CDN here.

        for _, pattern in ipairs({
          -- Mocha
          -- "./django/build/static/css/*.css",

          -- bootstrap dist
          -- "./django/build/node_modules/bootstrap/dist/css/bootstrap.css" --

          -- Flock
          -- "./django/build/static/css/flock/*.css"

          -- App
          "./django/build/static/css/app/*.css",

          -- WWW
          -- "./django/build/static/css/www/*.css"

          -- XP
          -- "./django/build/static/css/xp/*.css"

          -- Rubrics
          -- "./django/build/static/css/rubrics/*.css"
        }) do
          for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
            table.insert(sheets, file)
          end
        end

        return sheets
      end)(),
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        htmx = {
          filetypes = {
            "astro",
            "blade",
            "clojure",
            "eelixir",
            "elixir",
            "eruby",
            "haml",
            "handlebars",
            "heex",
            "html",
            "htmlangular",
            "htmldjango",
            "javascript",
            "javascriptreact",
            "liquid",
            "markdown",
            "mustache",
            "php",
            "razor",
            "rescript",
            "svelte",
            "templ",
            "twig",
            "typescript",
            "typescriptreact",
            "vue",
          },
        },
        tailwindcss = {
          filetypes_exclude = {
            "aspnetcorerazor",
            "astro-markdown",
            "django-html",
            "edge",
            "ejs",
            "erb",
            "gohtml",
            "gohtmltmpl",
            "hbs",
            "html-eex",
            "jade",
            "leaf",
            "markdown",
            "mdx",
            "njk",
            "nunjucks",
            "postcss",
            "reason",
            "slim",
            "sugarss",
          },
          filetypes = {
            "astro",
            "blade",
            "clojure",
            "css",
            "eelixir",
            "elixir",
            "eruby",
            "haml",
            "handlebars",
            "heex",
            "html",
            "htmlangular",
            "htmldjango",
            "javascript",
            "javascriptreact",
            "less",
            "liquid",
            "markdown",
            "mustache",
            "php",
            "razor",
            "rescript",
            "sass",
            "scss",
            "stylus",
            "svelte",
            "templ",
            "twig",
            "typescript",
            "typescriptreact",
            "vue",
          },
        },
      },
    },
  },
  -- Mason for LSPs
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "css-lsp",
        "css-variables-language-server",
        "html-lsp",
        "htmx-lsp",
      },
    },
  },
  -- Treesitter for config file syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
        "html",
        "css",
      })
    end,
  },
  -- Filetype associations for LSP warnings
  {
    "LazyVim/LazyVim",
    optional = true,
    opts = function()
      vim.filetype.add({
        pattern = {
          [".*%. jsx"] = "javascriptreact",
          [".*%.tsx"] = "typescriptreact",
          [".*%.gitlab%.ya?ml"] = "yaml.gitlab",
        },
      })
    end,
  },
}
