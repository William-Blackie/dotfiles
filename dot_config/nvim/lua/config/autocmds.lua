-- Filetype detection
vim.filetype.add({
  extension = {
    j2 = "htmldjango",
    jinja = "htmldjango",
    jinja2 = "htmldjango",
    html = function(path, _)
      local dir = vim.fs.dirname(path)
      if dir:match("templates") then
        local root = vim.fs.root(0, { "manage.py", "pyproject.toml" })
        if root then
          return "htmldjango"
        end
      end
      return "html"
    end,
  },
  filename = {
    ["compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["docker-compose.yml"] = "yaml.docker-compose",
  },
})

-- Spell check for git commits and markdown
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Chezmoi auto apply
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { os.getenv("HOME") .. "/.dotfiles/*" },
  callback = function(ev)
    local bufnr = ev.buf
    local edit_watch = function()
      require("chezmoi.commands.__edit").watch(bufnr)
    end
    vim.schedule(edit_watch)
  end,
})
