local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root .. "/dot_config/exact_nvim")
local plugins = vim.fn.stdpath("data") .. "/lazy/"
vim.opt.rtp:append(plugins .. "nvim-html-css")

local scratch = vim.fn.tempname()
vim.fn.mkdir(scratch, "p")
scratch = vim.uv.fs_realpath(scratch)
local count = 0
local function check(name, fn)
  fn()
  count = count + 1
  print("PASS " .. name)
end
local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect(actual))
end
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
local function buffer(lines)
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { 2, 5 })
end

local ok, err = xpcall(function()
  dofile(root .. "/dot_config/exact_nvim/lua/config/autocmds.lua")
  check("sort adds missing separators before inline comments", function()
    buffer({ "d = {", '    "z": 1,', '    "a": 2  # comment', "}" })
    vim.cmd.SortPythonDict()
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      "d = {",
      '    "a": 2,  # comment',
      '    "z": 1,',
      "}",
    })
    assert(not vim.treesitter.get_parser(0, "python"):parse()[1]:root():has_error())
  end)
  check("sort preserves multiline values and attached comments", function()
    buffer({ "d = {", '    "z": [', "        1,", "    ],", "    # a", '    "a": 2', "}" })
    vim.cmd.SortPythonDict()
    equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
      "d = {",
      "    # a",
      '    "a": 2,',
      '    "z": [',
      "        1,",
      "    ],",
      "}",
    })
  end)
  check("sort refuses unpacking and entries sharing a line", function()
    for _, lines in ipairs({
      { "d = {", '    "z": 1,', "    **other,", '    "a": 2', "}" },
      { "d = {", '    "z": 1, "a": 2,', "}" },
      { "d = {", '    "z": 1', "    ,", '    "a": 2', "}" },
    }) do
      buffer(lines)
      pcall(vim.cmd.SortPythonDict)
      equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), lines)
    end
  end)
  check("SQL callback tolerates absent maps and removes existing maps", function()
    vim.cmd.enew({ bang = true })
    vim.v.errmsg = ""
    vim.api.nvim_exec_autocmds("FileType", { pattern = "sql" })
    equal(vim.v.errmsg, "")
    vim.keymap.set("i", "<Left>", "x", { buffer = true })
    vim.keymap.set("i", "<Right>", "y", { buffer = true })
    vim.api.nvim_exec_autocmds("FileType", { pattern = "sql" })
    equal(vim.fn.maparg("<Left>", "i"), "")
    equal(vim.fn.maparg("<Right>", "i"), "")
  end)

  local a, b, plain = scratch .. "/a", scratch .. "/b", scratch .. "/plain"
  for _, dir in ipairs({ a, b, plain }) do
    write(dir .. "/.git", {}) -- Worktree-style root marker.
    write(dir .. "/index.html", { '<div class="project"></div>' })
  end
  write(a .. "/.envrc", { "export NVIM_TEST_PROJECT=A", "export NVIM_TEST_ONLY_A=yes" })
  write(b .. "/.envrc", { "export NVIM_TEST_PROJECT=B" })
  for _, dir in ipairs({ a, b }) do
    assert(vim.system({ "direnv", "allow", dir }):wait().code == 0)
  end
  check("direnv switches and restores on buffer and directory changes", function()
    vim.env.NVIM_TEST_PROJECT = "original"
    vim.env.NVIM_TEST_ONLY_A = nil
    vim.cmd.edit(a .. "/index.html")
    local env = require("lib.project_env")
    env.setup()
    equal(vim.env.NVIM_TEST_PROJECT, "A")
    equal(vim.env.NVIM_TEST_ONLY_A, "yes")
    vim.cmd.edit(b .. "/index.html")
    equal(vim.env.NVIM_TEST_PROJECT, "B")
    equal(vim.env.NVIM_TEST_ONLY_A, nil)
    vim.cmd.edit(plain .. "/index.html")
    equal(vim.env.NVIM_TEST_PROJECT, "original")
    vim.cmd.cd(a)
    equal(vim.env.NVIM_TEST_PROJECT, "A")
    vim.cmd.cd(plain)
    equal(vim.env.NVIM_TEST_PROJECT, "original")
  end)
  check(
    "unapproved direnv unloads the old project without executing the new one",
    function()
      local denied = scratch .. "/denied"
      write(denied .. "/.envrc", { "export NVIM_TEST_PROJECT=must-not-load" })
      write(denied .. "/index.html", { "" })
      vim.cmd.edit(a .. "/index.html")
      equal(vim.env.NVIM_TEST_PROJECT, "A")
      vim.cmd.edit(denied .. "/index.html")
      equal(vim.env.NVIM_TEST_PROJECT, "original")
      equal(vim.env.NVIM_TEST_ONLY_A, nil)
      vim.cmd.edit(plain .. "/index.html")
    end
  )
  check("direnv reloads watched files and passes the editor marker", function()
    write(a .. "/.envrc", {
      "export NVIM_TEST_PROJECT=A",
      'export NVIM_TEST_EDITOR="${NVIM_DIRENV:-0}"',
      'dotenv_if_exists "./settings.env"',
    })
    write(a .. "/settings.env", { "NVIM_TEST_WATCH=before" })
    assert(vim.system({ "direnv", "allow", a }):wait().code == 0)
    vim.cmd.edit(a .. "/index.html")
    equal(vim.env.NVIM_TEST_EDITOR, "1")
    equal(vim.env.NVIM_TEST_WATCH, "before")
    write(a .. "/settings.env", { "NVIM_TEST_WATCH=after" })
    -- Make the watched timestamp distinct without a wall-clock sleep.
    local future = os.time() + 2
    vim.uv.fs_utime(a .. "/settings.env", future, future)
    require("lib.project_env").update()
    equal(vim.env.NVIM_TEST_WATCH, "after")
    vim.cmd.edit(plain .. "/index.html")
    equal(vim.env.NVIM_TEST_WATCH, nil)
    equal(vim.env.NVIM_TEST_EDITOR, nil)
  end)
  check("CSS follows buffer roots and preserves linked styles", function()
    local css_a = a .. "/django/build/static/css/site/main.css"
    local css_b = b .. "/django/build/static/css/site/main.css"
    local linked = a .. "/linked.css"
    write(css_a, { ".a { color: red; }" })
    write(css_b, { ".b { color: blue; }" })
    write(linked, { ".linked { color: green; }" })
    local cache = require("html-css.cache")
    -- Seed parsed styles to avoid asynchronous file reads in this linking check.
    for _, path in ipairs({ css_a, css_b, linked }) do
      cache:update(path, { class = {}, id = {}, imports = {} })
    end
    vim.cmd.edit(a .. "/index.html")
    local buf_a = vim.api.nvim_get_current_buf()
    cache:link_sources(buf_a, { linked })
    require("lib.project_styles").setup({ enable_on = { "html" } })
    assert(cache._buffers[buf_a]._sources[css_a])
    assert(cache._buffers[buf_a]._sources[linked])
    vim.cmd.edit(b .. "/index.html")
    local buf_b = vim.api.nvim_get_current_buf()
    assert(cache._buffers[buf_b]._sources[css_b])
    assert(not cache._buffers[buf_b]._sources[css_a])
    vim.cmd.buffer(buf_a)
    assert(cache._buffers[buf_a]._sources[css_a])
    assert(cache._buffers[buf_a]._sources[linked])
  end)
end, debug.traceback)

vim.cmd.cd(root)
vim.fn.delete(scratch, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd.cquit(1)
end
print(string.format("%d Neovim checks passed", count))
vim.cmd.qa({ bang = true })
