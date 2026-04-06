-- Simple filetype detection
vim.filetype.add({
  extension = {
    j2 = "htmldjango",
    jinja = "htmldjango",
    jinja2 = "htmldjango",
    gotmpl = "gotmpl",
    helm = "helm",
    mdx = "markdown.mdx",
    templ = "templ",
  },
  filename = {
    ["go.work"] = "gowork",
    ["compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["docker-compose.yml"] = "yaml.docker-compose",
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitcommit", "markdown", "text" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

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
