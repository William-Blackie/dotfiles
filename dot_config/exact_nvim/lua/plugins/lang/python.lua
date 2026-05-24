---Python language support
---@type LazySpec
return {
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
