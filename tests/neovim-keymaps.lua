local root = vim.fn.getcwd()
local plugins = vim.fn.stdpath("data") .. "/lazy/"
for _, path in ipairs({
  root .. "/dot_config/exact_nvim",
  plugins .. "lazy.nvim",
  plugins .. "LazyVim",
  plugins .. "snacks.nvim",
}) do
  vim.opt.rtp:append(path)
end

local scratch = vim.fn.tempname()
local ok, err = xpcall(function()
  -- Initialize only the mapping infrastructure, without installing/loading the
  -- user's plugin collection or running project startup hooks.
  local specs = {
    {
      "folke/snacks.nvim",
      dir = plugins .. "snacks.nvim",
      keys = {
        { "<leader>gd", "<cmd>echo 'picker'<cr>" },
        { "<leader>gD", "<cmd>echo 'picker'<cr>" },
      },
    },
    {
      "ibhagwan/fzf-lua",
      dir = plugins .. "fzf-lua",
      keys = { { "<leader>gd", "<cmd>echo 'fzf'<cr>" } },
    },
  }
  vim.g.mapleader = " "
  vim.go.loadplugins = true
  vim.list_extend(
    specs,
    dofile(root .. "/dot_config/exact_nvim/lua/plugins/diffview.lua")
  )
  require("lazy").setup(specs, {
    install = { missing = false },
    checker = { enabled = false },
    change_detection = { enabled = false },
    performance = { rtp = { reset = false } },
    pkg = { enabled = false },
  })
  _G.Snacks = require("snacks")
  package.loaded["lib.project_env"] = { setup = function() end }
  package.loaded["config.lazy"] = true
  package.loaded["config.local"] = true
  dofile(root .. "/dot_config/exact_nvim/init.lua")
  local config = require("lazyvim.config")
  config.load("keymaps")
  -- Let Snacks finish its deferred mapping registrations.
  vim.wait(200, function()
    return false
  end)
  local mapping = vim.fn.maparg("<C-h>", "n", false, true)
  assert(mapping.desc == "Window left", vim.inspect(mapping))
  assert(type(mapping.callback) == "function")
  print("PASS custom keymaps take precedence over LazyVim defaults")
  for _, key in ipairs({ "gd", "gD", "gf", "gF", "gH", "gM", "gq" }) do
    local git_mapping = vim.fn.maparg(" " .. key, "n", false, true)
    assert(
      (git_mapping.desc or ""):find("Diffview:", 1, true),
      key .. " leader=" .. tostring(vim.g.mapleader) .. " " .. vim.inspect(git_mapping)
    )
  end
  require("lazy").load({ plugins = { "diffview.nvim", "snacks.nvim" } })
  local toggle = vim.fn.maparg(" gd", "n", false, true).callback
  assert(type(toggle) == "function")
  assert(vim.fn.maparg(" gf", "n"):find("DiffviewFileHistory", 1, true))
  assert(vim.fn.maparg(" gH", "v"):find("DiffviewFileHistory", 1, true))
  io.stdout:write("PASS Diffview Git mappings win over picker and LazyVim mappings\n")

  vim.fn.mkdir(scratch, "p")
  local function git(...)
    local result = vim.system({ "git", "-C", scratch, ... }):wait()
    assert(result.code == 0, result.stderr)
  end
  git("init", "--quiet")
  local file = scratch .. "/example.txt"
  vim.fn.writefile({ "committed" }, file)
  git("add", "example.txt")
  git(
    "-c",
    "user.name=Test",
    "-c",
    "user.email=test@example.com",
    "-c",
    "commit.gpgsign=false",
    "commit",
    "--quiet",
    "-m",
    "fixture"
  )
  vim.fn.writefile({ "working change" }, file)
  vim.cmd.cd(vim.fn.fnameescape(scratch))
  -- Preload the file so Diffview uses a buffer with the default 'bufhidden'.
  local buf = vim.fn.bufadd(file)
  vim.fn.bufload(buf)
  vim.o.hidden = false
  local original_tab = vim.api.nvim_get_current_tabpage()

  for _, close in ipairs({
    function()
      vim.cmd.DiffviewClose()
    end,
    toggle,
    function()
      vim.cmd.normal("q")
    end,
  }) do
    vim.bo[buf].bufhidden = ""
    toggle()
    local view = require("diffview.lib").get_current_view()
    assert(view, "Toggle should open Diffview")
    assert(
      vim.wait(5000, function()
        return view.cur_entry and view.cur_entry.opened
      end),
      "Diffview did not finish opening the file"
    )
    local shown = false
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
      if vim.api.nvim_win_get_buf(win) == buf then
        shown = true
        vim.api.nvim_win_call(win, function()
          assert(vim.fn.maparg("q", "n"):find("DiffviewClose", 1, true))
        end)
      end
    end
    assert(shown, "Expected working file in a diff pane")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved edit" })
    -- An additional modified pane exercises E445 ("Other window contains changes").
    local other = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(other, scratch .. "/other-" .. other .. ".txt")
    vim.cmd.vsplit()
    vim.api.nvim_win_set_buf(0, other)
    vim.api.nvim_buf_set_lines(other, 0, -1, false, { "another unsaved edit" })
    view.panel:focus()
    close()
    assert(vim.api.nvim_get_current_tabpage() == original_tab)
    assert(#vim.api.nvim_list_tabpages() == 1)
    assert(not require("diffview.lib").get_current_view())
    assert(vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified)
    assert(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "unsaved edit")
    assert(vim.api.nvim_buf_is_loaded(other) and vim.bo[other].modified)
    assert(vim.api.nvim_buf_get_lines(other, 0, -1, false)[1] == "another unsaved edit")
    assert(vim.fn.readfile(file)[1] == "working change", "Close must not save edits")
    assert(not vim.o.hidden, "Close must not change the global hidden option")
  end
  io.stdout:write("PASS Diffview command, toggle, and q preserve unsaved edits\n")
end, debug.traceback)
vim.fn.delete(scratch, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd.cquit(1)
end
vim.cmd.qa({ bang = true })
