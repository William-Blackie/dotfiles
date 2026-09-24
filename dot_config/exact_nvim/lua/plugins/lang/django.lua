---Django language support
---@type LazySpec
local django_root_markers = { "manage.py", "pyproject.toml", ".git" }

---@param dir string|nil
---@return boolean
local function is_templates_dir(dir)
  return dir ~= nil
    and (
      dir:match("^templates$")
      or dir:match("^templates/")
      or dir:match("/templates$")
      or dir:match("/templates/")
    )
end

vim.filetype.add({
  extension = {
    html = function(path, _)
      local dir = vim.fs.dirname(path)
      if is_templates_dir(dir) and vim.fs.root(path, django_root_markers) then
        return "htmldjango"
      end
      return "html"
    end,
  },
})

-- There is no dedicated "htmldjango" treesitter grammar. Without this, every
-- treesitter-dependent feature on htmldjango buffers (highlighting, and
-- notably html-css's `K` hover / definition lookups, which walk the
-- treesitter tree to find `class`/`id` attributes) silently gets no parser
-- and falls straight through to plain LSP hover.
vim.treesitter.language.register("html", "htmldjango")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, { "html" })
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "djlint",
        "django-template-lsp",
        "ty",
      },
    },
  },
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
}
