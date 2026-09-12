-- Filetype detection
vim.filetype.add({
  extension = {
    rest = "http",
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
  pattern = { os.getenv("HOME") .. "/dotfiles/*" },
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
  if #items == 0 then
    return
  end

  table.remove(items, currline)
  vim.fn.setqflist(items, "r")
  if #items == 0 then
    vim.cmd.cclose()
    return
  end

  vim.cmd(("normal! %dG"):format(math.min(currline, #items)))
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

  if vim.fn.executable("rg") ~= 1 then
    vim.notify("Grep requires ripgrep (rg)", vim.log.levels.ERROR)
    return
  end

  latest_greps[pattern] = true
  path = path or "."

  local result = vim
    .system({
      "rg",
      "--vimgrep",
      "--smart-case",
      "--hidden",
      "--glob",
      "!{.git,node_modules}/**",
      "--",
      pattern,
      path,
    }, { text = true })
    :wait()

  if result.code > 1 then
    vim.notify(result.stderr or "rg failed", vim.log.levels.ERROR)
    return
  end

  local lines = vim.split(result.stdout or "", "\n", { plain = true, trimempty = true })
  vim.fn.setqflist({}, "r", {
    title = "rg: " .. pattern,
    lines = lines,
    efm = "%f:%l:%c:%m",
  })

  if #lines == 0 then
    vim.notify("No matches")
    return
  end

  vim.cmd.copen()
end

-- Replace in quickfix
-- confirm: true for confirmation, false/nil for no confirmation
local function substitute_delimiter(original, replacement)
  for _, delimiter in ipairs({ "/", "#", "~", "@" }) do
    if
      not original:find(delimiter, 1, true)
      and not replacement:find(delimiter, 1, true)
    then
      return delimiter
    end
  end

  return "/"
end

local function escape_substitute(value, delimiter, is_replacement)
  value = vim.fn.escape(value, "\\" .. delimiter)
  value = value:gsub("|", "\\|")
  if is_replacement then
    value = value:gsub("&", "\\&")
  end
  return value
end

local function Replace(original, replacement, confirm)
  if not original or original == "" or replacement == nil then
    return
  end

  replacement = replacement or ""
  local delimiter = substitute_delimiter(original, replacement)
  local search = escape_substitute(original, delimiter, false)
  local replace = escape_substitute(replacement, delimiter, true)
  local flags = confirm and "gce" or "ge"
  vim.cmd(
    string.format(
      "cfdo %%s%s%s%s%s%s%s",
      delimiter,
      search,
      delimiter,
      replace,
      delimiter,
      flags
    )
  )
end

local function LatestGreps()
  local keys = {}
  for k in pairs(latest_greps) do
    table.insert(keys, k)
  end
  return keys
end

-- Grep
vim.api.nvim_create_user_command("Grep", function(opts)
  Grep(opts.fargs[1], opts.fargs[2])
end, { nargs = "+", complete = "file" })

-- Replace
vim.api.nvim_create_user_command("Replace", function(opts)
  Replace(opts.fargs[1], opts.fargs[2], opts.fargs[3])
end, {
  nargs = "+",
  complete = function()
    return LatestGreps()
  end,
})

-- Git
-- Open files changed on this branch
local function open_git_files(mode)
  local root = require("lib.utils").git_root()
  if not root then
    vim.notify("Not in a git repo", vim.log.levels.ERROR)
    return
  end

  local files = {}
  local seen = {}

  local function collect(args)
    local result = vim.system(args, { cwd = root, text = true }):wait()
    if result.code ~= 0 then
      vim.notify(result.stderr, vim.log.levels.ERROR)
      return false
    end

    for _, file in
      ipairs(vim.split(result.stdout, "\0", { plain = true, trimempty = true }))
    do
      if not seen[file] then
        seen[file] = true
        table.insert(files, root .. "/" .. file)
      end
    end

    return true
  end

  if mode == "origin" then
    if
      not collect({
        "git",
        "diff",
        "--name-only",
        "-z",
        "--diff-filter=ACMR",
        "--merge-base",
        "origin",
      })
    then
      return
    end
  else
    if not collect({ "git", "diff", "--name-only", "-z", "--diff-filter=ACMR" }) then
      return
    end
    if
      not collect({ "git", "diff", "--name-only", "-z", "--diff-filter=ACMR", "--cached" })
    then
      return
    end
  end

  if #files == 0 then
    vim.notify("No changed files")
    return
  end

  for _, file in ipairs(files) do
    vim.fn.bufadd(file)
  end

  vim.cmd.edit(vim.fn.fnameescape(files[1]))
  vim.notify(("Opened %d changed files"):format(#files))
end

vim.api.nvim_create_user_command("OpenDiffFiles", function()
  open_git_files("local")
end, { desc = "Open staged and unstaged git diff files" })

vim.api.nvim_create_user_command("OpenOriginFiles", function()
  open_git_files("origin")
end, { desc = "Open files changed vs origin merge-base" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "mermaid",
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    vim.keymap.set(
      "n",
      "<leader>mp",
      "<cmd>MermaidPreview<CR>",
      { buffer = buf, desc = "Mermaid Preview" }
    )
    vim.keymap.set(
      "n",
      "<leader>mf",
      "<cmd>MermaidFormat<CR>",
      { buffer = buf, desc = "Mermaid Format" }
    )
    vim.keymap.set(
      "n",
      "<leader>mr",
      "<cmd>MermaidRender<CR>",
      { buffer = buf, desc = "Mermaid Render" }
    )
    vim.keymap.set(
      "n",
      "<leader>mc",
      "<cmd>MermaidCopyURL<CR>",
      { buffer = buf, desc = "Mermaid Copy URL" }
    )
    vim.keymap.set(
      "n",
      "<leader>mx",
      "<cmd>MermaidPreviewStop<CR>",
      { buffer = buf, desc = "Mermaid Stop Preview" }
    )
  end,
})

-- Insert current ISO date
vim.api.nvim_create_user_command("Datenow", function()
  vim.api.nvim_put({ vim.fn.strftime("%Y-%m-%d") }, "c", true, true)
end, { desc = "Insert current ISO date" })

vim.api.nvim_create_user_command("SortPythonDict", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor[1] - 1
  local cursor_col = cursor[2]

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "python")

  if not ok or not parser then
    vim.notify("Python Tree-sitter parser is not installed", vim.log.levels.ERROR)
    return
  end

  local trees = parser:parse()
  local tree = trees and trees[1]

  if not tree then
    vim.notify("Could not parse this buffer", vim.log.levels.ERROR)
    return
  end

  local node =
    tree:root():named_descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)

  while node and node:type() ~= "dictionary" do
    node = node:parent()
  end

  if not node then
    vim.notify("Cursor is not inside a Python dictionary", vim.log.levels.ERROR)
    return
  end

  if node:has_error() then
    vim.notify("Cannot sort a dictionary with syntax errors", vim.log.levels.ERROR)
    return
  end

  local dict_start_row, _, dict_end_row = node:range()
  local entries = {}

  for child in node:iter_children() do
    if child:named() and child:type() ~= "pair" and child:type() ~= "comment" then
      vim.notify("Dictionary unpacking is not supported", vim.log.levels.ERROR)
      return
    end
    if child:type() == "pair" then
      local key_node = child:named_child(0)
      local pair_start_row, _, pair_end_row, pair_end_col = child:range()
      local separator = child:next_sibling()
      while separator and separator:type() == "comment" do
        separator = separator:next_sibling()
      end
      if separator and separator:type() == "," then
        local separator_row = separator:range()
        if separator_row ~= pair_end_row then
          vim.notify("Commas must follow their dictionary values", vim.log.levels.ERROR)
          return
        end
      end

      if not key_node then
        vim.notify("Could not read a dictionary key", vim.log.levels.ERROR)
        return
      end

      if pair_start_row == dict_start_row or pair_end_row >= dict_end_row then
        vim.notify(
          "Each key and the closing brace must start on separate lines",
          vim.log.levels.ERROR
        )
        return
      end

      if entries[#entries] and pair_start_row <= entries[#entries].pair_end_row then
        vim.notify("Each dictionary entry must have its own lines", vim.log.levels.ERROR)
        return
      end

      local key = vim.treesitter.get_node_text(key_node, bufnr)
      local first = key:sub(1, 1)
      local last = key:sub(-1)

      if (first == "'" or first == '"') and last == first then
        key = key:sub(2, -2)
      end

      table.insert(entries, {
        key = key:lower(),
        pair_start_row = pair_start_row,
        pair_end_row = pair_end_row,
        pair_end_col = pair_end_col,
      })
    end
  end

  if #entries < 2 then
    vim.notify("Dictionary has fewer than two entries")
    return
  end

  -- Put entries into their current source order.
  table.sort(entries, function(a, b)
    return a.pair_start_row < b.pair_start_row
  end)

  -- Attach comments and blank lines immediately above a key
  -- to that dictionary entry.
  for index, entry in ipairs(entries) do
    local start_row = entry.pair_start_row
    local minimum_row

    if index == 1 then
      minimum_row = dict_start_row + 1
    else
      minimum_row = entries[index - 1].pair_end_row + 1
    end

    while start_row > minimum_row do
      local previous_line = vim.api.nvim_buf_get_lines(
        bufnr,
        start_row - 1,
        start_row,
        false
      )[1] or ""

      local is_comment = previous_line:match("^%s*#") ~= nil
      local is_blank = previous_line:match("^%s*$") ~= nil

      if not is_comment and not is_blank then
        break
      end

      start_row = start_row - 1
    end

    entry.start_row = start_row
    entry.original_index = index
  end

  -- Capture each complete entry block.
  for index, entry in ipairs(entries) do
    local end_row

    if entries[index + 1] then
      end_row = entries[index + 1].start_row
    else
      end_row = dict_end_row
    end

    entry.lines = vim.api.nvim_buf_get_lines(bufnr, entry.start_row, end_row, false)
    -- Include a separator before any inline comment, even for the original last pair.
    local line_index = entry.pair_end_row - entry.start_row + 1
    local line = entry.lines[line_index]
    local suffix = line:sub(entry.pair_end_col + 1)
    if not suffix:match("^%s*,") then
      entry.lines[line_index] = line:sub(1, entry.pair_end_col) .. "," .. suffix
    end
  end

  local replacement_start = entries[1].start_row

  -- Stable, case-insensitive key sort.
  table.sort(entries, function(a, b)
    if a.key == b.key then
      return a.original_index < b.original_index
    end

    return a.key < b.key
  end)

  local replacement = {}

  for _, entry in ipairs(entries) do
    vim.list_extend(replacement, entry.lines)
  end

  vim.api.nvim_buf_set_lines(bufnr, replacement_start, dict_end_row, false, replacement)

  vim.notify("Python dictionary sorted by key")
end, {
  desc = "Sort Python dictionary under cursor by key",
  force = true,
})

-- dadbod fix: https://github.com/neovim/neovim/issues/26977
vim.api.nvim_create_autocmd("Filetype", {
  pattern = "sql",
  callback = function()
    pcall(vim.keymap.del, "i", "<left>", { buffer = true })
    pcall(vim.keymap.del, "i", "<right>", { buffer = true })
  end,
})
