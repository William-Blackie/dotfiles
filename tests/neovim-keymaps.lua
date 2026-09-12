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
  assert(vim.fn.maparg(" gd", "n"):find("DiffviewOpen", 1, true))
  assert(vim.fn.maparg(" gf", "n"):find("DiffviewFileHistory", 1, true))
  assert(vim.fn.maparg(" gH", "v"):find("DiffviewFileHistory", 1, true))
  print("PASS Diffview Git mappings win over picker and LazyVim mappings")
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd.cquit(1)
end
vim.cmd.qa({ bang = true })
