---Neovim options and provider configuration

-- Python LSP: ty
vim.g.lazyvim_python_lsp = "ty"
vim.opt.textwidth = 80

-- Neovim provider envs
local nvim_env = vim.fn.stdpath("data") .. "/env"
local python_host = nvim_env .. "/python/.venv/bin/python"
local python_bin = nvim_env .. "/python/.venv/bin"
local node_bin = nvim_env .. "/node/bin"
local node_host = nvim_env .. "/node/bin/neovim-node-host"
local ruby_host = nvim_env .. "/ruby/bin/neovim-ruby-host"
local ruby_bin = "/opt/homebrew/opt/ruby/bin"
local ruby_gems = nvim_env .. "/ruby/gems"
local perl_host = nvim_env .. "/perl/bin/perl"
local perl_bin = nvim_env .. "/perl/bin"
local perl_lib = nvim_env .. "/perl/lib/perl5"

if vim.fn.executable(python_host) == 1 then
  vim.env.PATH = python_bin .. ":" .. vim.env.PATH
end

if vim.fn.executable(node_bin .. "/node") == 1 then
  vim.env.PATH = node_bin .. ":" .. vim.env.PATH
end

if vim.fn.executable(ruby_bin .. "/ruby") == 1 then
  vim.env.GEM_HOME = ruby_gems
  vim.env.GEM_PATH = ruby_gems
  vim.env.PATH = ruby_bin .. ":" .. ruby_gems .. "/bin:" .. vim.env.PATH
end

if vim.fn.executable(perl_host) == 1 then
  vim.env.PERL5LIB = perl_lib .. ":" .. (vim.env.PERL5LIB or "")
  vim.env.PATH = perl_bin .. ":" .. vim.env.PATH
end

if vim.fn.executable(python_host) == 1 then
  vim.g.python3_host_prog = python_host
end

if vim.fn.executable(node_host) == 1 then
  vim.g.node_host_prog = node_host
end

if vim.fn.executable(ruby_host) == 1 then
  vim.g.ruby_host_prog = ruby_host
end

if vim.fn.executable(perl_host) == 1 then
  vim.g.perl_host_prog = perl_host
end

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

-- Better diffs
vim.opt.diffopt:append("algorithm:histogram")
vim.opt.diffopt:append("indent-heuristic")

-- Spell check
vim.opt.spell = true
vim.opt.spelloptions:append("noplainbuffer")
vim.opt.spellfile = vim.fn.stdpath("config") .. "/spell/en.utf-8.add"

-- ESLint
vim.g.lazyvim_eslint_auto_format = true

-- Blink.cmp
-- Build from main
vim.g.lazyvim_blink_main = false
-- Turn off the AI.
vim.g.ai_cmp = false
