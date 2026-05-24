-- Filetype detection
vim.filetype.add({
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

-- Quickfix
-- https://gosukiwi.github.io/vim/2022/04/19/vim-advanced-search-and-replace.html
-- Quickfix: Remove entry at cursor
local function qf_remove_at_cursor()
  local currline = vim.fn.line(".")
  local items = vim.fn.getqflist()
  table.remove(items, currline)
  vim.fn.setqflist(items, "r")
  vim.cmd("normal! " .. currline .. "G")
end

vim.api.nvim_create_augroup("quickfix", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "quickfix",
  pattern = "qf",
  callback = function()
    vim.keymap.set("n", "x", qf_remove_at_cursor, { buffer = true, silent = true })
  end,
})

-- Grep/Replace with latest patterns
local latest_greps = {}

local function Grep(pattern, path)
  pattern = pattern or ""
  if pattern == "" then
    return
  end
  latest_greps[pattern] = true
  path = path or "."
  local cmd = string.format(
    'silent! grep! "%s" %s | redraw! | copen',
    pattern:gsub('"', '\\"'),
    path
  )
  vim.cmd(cmd)
end

-- Replace in quickfix
-- confirm: true for confirmation, false/nil for no confirmation
local function Replace(original, replacement, confirm)
  if not original or original == "" or not replacement or replacement == "" then
    return
  end
  local flags = confirm and "gce" or "ge"
  local cmd =
    string.format("cfdo %%s/%s/%s/%s", vim.fn.escape(original, "/"), replacement, flags)
  vim.cmd(cmd)
end

local function LatestGreps()
  local keys = {}
  for k in pairs(latest_greps) do
    table.insert(keys, k)
  end
  return keys
end

vim.api.nvim_create_user_command("Grep", function(opts)
  Grep(opts.fargs[1], opts.fargs[2])
end, { nargs = "+", complete = "file" })

vim.api.nvim_create_user_command("Replace", function(opts)
  Replace(opts.fargs[1], opts.fargs[2], opts.fargs[3])
end, {
  nargs = "+",
  complete = function()
    return LatestGreps()
  end,
})

vim.keymap.set("n", "<Leader>g", ":Grep ", { noremap = true })
vim.keymap.set("n", "<Leader>r", function()
  vim.api.nvim_feedkeys(":Replace <Tab>", "t", false)
end, { noremap = true, silent = true })
