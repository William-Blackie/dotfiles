local M = {}

--- Show floating card panel with Markdown highlighting
--- @param result table Analysis result from the python backend
--- @param query_str string Original ORM query text
function M.show_panel(result, query_str)
  -- 1. Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- 2. Build Markdown content
  local content = {}
  local function append_multiline(value)
    local text = tostring(value or ""):gsub("\r\n", "\n")
    if text == "" then
      table.insert(content, "")
      return
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
      table.insert(content, line)
    end
  end

  table.insert(content, "# 📊 Django ORM Analysis Report")
  table.insert(content, string.rep("─", 50))
  table.insert(content, "")

  -- Complexity status header
  local profile_emoji = "✅"
  local profile_tag = "OPTIMAL"
  local profile_desc = "Excellent structure."

  if
    string.find(result.complexity, "O(N)", 1, true)
    or string.find(result.complexity, "O(N * M)", 1, true)
    or string.find(result.complexity, "O(K)", 1, true)
  then
    profile_emoji = "🔥"
    profile_tag = "CRITICAL"
    profile_desc = "Requires indexing or query restructuring."
  elseif string.find(result.complexity, "O(N log N)", 1, true) then
    profile_emoji = "⚠️"
    profile_tag = "SUBOPTIMAL"
    profile_desc = "Sort or group-by detected — consider an index."
  elseif #result.warnings > 0 then
    profile_emoji = "⚠️"
    profile_tag = "WARNING"
    profile_desc = "Minor performance risks detected."
  end

  table.insert(
    content,
    "### " .. profile_emoji .. " Performance Profile [" .. profile_tag .. "]"
  )
  table.insert(content, "> " .. profile_desc)
  table.insert(content, "")
  table.insert(content, "- **Time Complexity**  : `" .. result.complexity .. "`")
  table.insert(content, "- **Space Complexity** : `O(R * C)` [Row/Column bounds]")
  table.insert(content, "- **Database Engine**  : `" .. result.engine .. "`")
  table.insert(content, "")

  -- Warnings section
  if #result.warnings > 0 then
    table.insert(content, "## ⚠️ Warnings")
    for _, w in ipairs(result.warnings) do
      table.insert(content, "- " .. w)
    end
    table.insert(content, "")
  end

  -- Recommendations section
  if #result.suggestions > 0 then
    table.insert(content, "## 💡 Optimization Suggestions")
    for _, s in ipairs(result.suggestions) do
      table.insert(content, "- " .. s)
    end
    table.insert(content, "")
  end

  -- Highlighted Python ORM Statement
  table.insert(content, "## 🐍 Python ORM Statement")
  table.insert(content, "```python")
  append_multiline(query_str)
  table.insert(content, "```")
  table.insert(content, "")

  -- Highlighted Compiled SQL
  table.insert(content, "## 🔍 Compiled SQL Statement")
  table.insert(content, "```sql")
  append_multiline(result.sql)
  table.insert(content, "```")
  table.insert(content, "")

  -- Execution Plan table
  if result.plan and #result.plan > 0 then
    table.insert(content, "## 🛠️ Database Explain Plan")
    table.insert(content, "```text")
    for _, row in ipairs(result.plan) do
      table.insert(content, table.concat(row, " | "))
    end
    table.insert(content, "```")
    table.insert(content, "")
  end

  -- Add hotkeys tip
  table.insert(content, string.rep("─", 50))
  table.insert(content, "*Press <q> or <ESC> to dismiss this report*")

  -- Write lines to buffer
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Set buffer properties (read-only, markdown filetype)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"

  -- 3. Calculate panel dimensions and layout centering
  local config = require("django-orm-analyzer").config
  local width = math.floor(vim.o.columns * config.window.width)
  local height = math.floor(vim.o.lines * config.window.height)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- 4. Open Neovim floating window
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = config.window.border,
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set window styles and options
  vim.wo[win].winhl = "Normal:DjangoORMBg,FloatBorder:DjangoORMBorder"
  vim.wo[win].wrap = true

  -- 5. Define quick closure keymaps inside buffer
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true })
  end

  map("n", "q", ":close<CR>")
  map("n", "<ESC>", ":close<CR>")
end

return M
