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

return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "djlint",
        "django-language-server",
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