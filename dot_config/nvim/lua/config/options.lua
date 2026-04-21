-- Python LSP: ty
vim.g.lazyvim_python_lsp = "ty"
vim.opt.textwidth = 80

-- Indentation: 4 spaces for Python
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- UI
vim.opt.relativenumber = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.cursorline = true

-- Spell check
vim.opt.spell = true
vim.opt.spelloptions:append("noplainbuffer")
vim.opt.spellfile = vim.fs.abspath("~/.config/nvim/spell/en.utf-8.add")

-- ESLint
vim.g.lazyvim_eslint_auto_format = true
