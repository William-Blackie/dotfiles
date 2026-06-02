local M = {}

local ns_id = vim.api.nvim_create_namespace("django-orm-analyzer")

-- Track containers where plugin files have already been copied this session
local _docker_files_synced = {}

-- Get the directory of the current lua module
local function get_plugin_dir()
  local source = debug.getinfo(1).source
  if source:sub(1, 1) == "@" then
    -- Strip @ and get directory containing this core.lua file
    local file_path = source:sub(2)
    local plugin_root = vim.fs.dirname(file_path)
    return plugin_root
  end
  return nil
end

-- Safely extract visual selection text
local function get_visual_selection()
  local s_start = vim.fn.getpos("'<")
  local s_end = vim.fn.getpos("'>")
  local n_lines = math.abs(s_end[2] - s_start[2]) + 1
  local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
  if #lines == 0 then
    return ""
  end

  -- Handle visual block selections and inline selections
  lines[1] = string.sub(lines[1], s_start[3])
  if n_lines == 1 then
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
  else
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
  end
  return table.concat(lines, "\n")
end

-- Extract the enclosing Python function, including its class header when
-- available so QuerySet model inference can use FooQuerySet naming.
local function get_enclosing_python_function()
  local cursor_line = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if #lines == 0 then
    return nil, nil
  end

  local start_idx = nil
  local start_indent = nil
  for i = cursor_line, 1, -1 do
    local line = lines[i]
    local indent, name = line:match("^(%s*)def%s+([%w_]+)%s*%(")
    if indent and name then
      start_idx = i
      start_indent = #indent
      break
    end
  end

  if not start_idx or not start_indent then
    return nil, nil
  end

  local end_idx = #lines
  for i = start_idx + 1, #lines do
    local line = lines[i]
    local is_blank = line:match("^%s*$") ~= nil
    local indent = #(line:match("^(%s*)") or "")
    if not is_blank and indent <= start_indent then
      end_idx = i - 1
      break
    end
  end

  local class_idx = nil
  for i = start_idx - 1, 1, -1 do
    local line = lines[i]
    local indent = #(line:match("^(%s*)") or "")
    if line:match("^%s*class%s+[%w_]+") and indent < start_indent then
      class_idx = i
      break
    end
    if not line:match("^%s*$") and indent < start_indent then
      break
    end
  end

  local block = vim.api.nvim_buf_get_lines(0, start_idx - 1, end_idx, false)
  if #block == 0 then
    return nil, nil
  end
  if class_idx then
    table.insert(block, 1, lines[class_idx])
  end
  return table.concat(block, "\n"), start_idx
end

-- Get query text and line number from buffer
local function get_query_text()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Exit visual mode to set the '< and '> marks
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<ESC>", true, false, true),
      "x",
      true
    )
    return get_visual_selection(), vim.fn.line("'<")
  else
    local function_text, function_line = get_enclosing_python_function()
    if function_text then
      return function_text, function_line
    end
    local line = vim.api.nvim_get_current_line()
    return line, vim.fn.line(".")
  end
end

-- Find Django project root where manage.py is
local function find_project_root()
  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    file_path = vim.fn.getcwd()
  end

  local manage_py_list = vim.fs.find({ "manage.py" }, { path = file_path, upward = true })
  if #manage_py_list > 0 then
    return vim.fs.dirname(manage_py_list[1])
  end
  return vim.fn.getcwd()
end

-- ---------------------------------------------------------------------------
-- Docker helpers
-- ---------------------------------------------------------------------------

--- Copy a local file into a running Docker container at a given path.
--- Returns true on success, false + error message on failure.
local function docker_copy_file(container, local_path, remote_path)
  local remote_dir = vim.fn.fnamemodify(remote_path, ":h")
  -- Ensure the remote directory exists
  local mkdir_result = vim.fn.system({
    "docker",
    "exec",
    container,
    "sh",
    "-c",
    "mkdir -p " .. vim.fn.shellescape(remote_dir),
  })
  if vim.v.shell_error ~= 0 then
    return false, "docker exec mkdir failed: " .. mkdir_result
  end

  local cp_result = vim.fn.system({
    "docker",
    "cp",
    local_path,
    container .. ":" .. remote_path,
  })
  if vim.v.shell_error ~= 0 then
    return false, "docker cp failed: " .. cp_result
  end
  return true, nil
end

--- Ensure the plugin's Python files are present inside the container.
--- Copies django_parser.py and the django_orm_analyzer package.
--- Returns remote_parser_path on success or nil + err.
local function ensure_docker_files(container, plugin_dir)
  if _docker_files_synced[container] then
    return _docker_files_synced[container], nil
  end

  local remote_base = "/tmp/.django_orm_analyzer_plugin"

  -- Copy the single-file entry point
  local parser_local = plugin_dir .. "/django_parser.py"
  local parser_remote = remote_base .. "/django_parser.py"
  local ok, err = docker_copy_file(container, parser_local, parser_remote)
  if not ok then
    return nil, err
  end

  -- Copy the whole django_orm_analyzer package directory
  local pkg_local = plugin_dir .. "/django_orm_analyzer"
  local pkg_remote = remote_base .. "/django_orm_analyzer"

  -- docker cp copies the dir itself, so we copy into the parent
  local cp_pkg = vim.fn.system({
    "docker",
    "cp",
    pkg_local,
    container .. ":" .. remote_base .. "/",
  })
  if vim.v.shell_error ~= 0 then
    return nil, "docker cp package failed: " .. cp_pkg
  end

  -- Ensure the remote package is importable (add __init__ if absent)
  vim.fn.system({
    "docker",
    "exec",
    container,
    "sh",
    "-c",
    "touch " .. vim.fn.shellescape(pkg_remote .. "/__init__.py"),
  })

  _docker_files_synced[container] = parser_remote
  return parser_remote, nil
end

--- Build the command list for running the parser.
--- Uses docker exec when a container is configured, otherwise python3.
local function build_command(plugin_dir, project_root, query_str)
  local config = require("django-orm-analyzer").config
  local container = config.docker_container

  if container and container ~= "" then
    -- Ensure plugin files exist inside container
    local remote_parser, err = ensure_docker_files(container, plugin_dir)
    if not remote_parser then
      return nil, err
    end

    -- The project root inside the container: use config override or same path
    local remote_project_root = config.docker_project_root or project_root

    return {
      "docker",
      "exec",
      "-e",
      "DJANGO_ORM_ANALYZER_SKIP_VENV=1",
      container,
      "python3",
      remote_parser,
      remote_project_root,
      query_str,
    },
      nil
  end

  -- Local execution
  local python_cmd = config.python_cmd or "python3"
  local parser_path = plugin_dir .. "/django_parser.py"
  return {
    python_cmd,
    parser_path,
    project_root,
    query_str,
  }, nil
end

-- ---------------------------------------------------------------------------
-- Main analysis
-- ---------------------------------------------------------------------------

---Extracts query text from buffer context and runs asynchronous python
---complexity analysis. Supports both local and Docker container environments.
function M.analyze_query()
  local query_str, line_num = get_query_text()
  if not query_str or query_str:gsub("%s+", "") == "" then
    vim.notify(
      "Django ORM Analyzer: No query selected or empty line.",
      vim.log.levels.WARN
    )
    return
  end

  local plugin_dir = get_plugin_dir()
  if not plugin_dir then
    vim.notify(
      "Django ORM Analyzer: Could not resolve plugin path.",
      vim.log.levels.ERROR
    )
    return
  end

  local project_root = find_project_root()

  -- Clear previous virtual text & diagnostics for this namespace
  vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
  vim.diagnostic.reset(ns_id, 0)

  local cmd, cmd_err = build_command(plugin_dir, project_root, query_str)
  if not cmd then
    vim.notify(
      "Django ORM Analyzer: " .. (cmd_err or "Command build failed"),
      vim.log.levels.ERROR
    )
    return
  end
  local config = require("django-orm-analyzer").config
  local mode = "local"
  if config.docker_container and config.docker_container ~= "" then
    mode = "docker: " .. config.docker_container
  end
  vim.notify("Analyzing Django ORM Query (" .. mode .. ")...", vim.log.levels.INFO)

  local stdout_chunks = {}
  local stderr_chunks = {}

  -- Asynchronous execution
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_chunks, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_chunks, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      local stdout_str = table.concat(stdout_chunks, "\n")
      local stderr_str = table.concat(stderr_chunks, "\n")

      if exit_code ~= 0 then
        vim.notify(
          "Django ORM Analyzer process exited with error: " .. stderr_str,
          vim.log.levels.ERROR
        )
        return
      end

      -- Extract the JSON block from stdout in case of noisy startup logs
      local json_start = stdout_str:find('{"success":')
      if json_start then
        stdout_str = stdout_str:sub(json_start)
      end

      local success, result = pcall(vim.fn.json_decode, stdout_str)
      if not success then
        vim.notify(
          "Django ORM Analyzer: Failed to parse execution response. " .. stdout_str,
          vim.log.levels.ERROR
        )
        return
      end

      if not result.success then
        vim.notify(
          "ORM Evaluation Failed: " .. (result.error or "Unknown error"),
          vim.log.levels.ERROR
        )
        if result.traceback then
          print(result.traceback)
        end
        return
      end

      -- Style virtual text based on complexity warning levels
      local config = require("django-orm-analyzer").config
      if config.virtual_text.enabled then
        local vt_text = config.virtual_text.prefix .. "Complexity: " .. result.complexity
        local hl_group = "DjangoORMVirtualTextOpt"

        if
          string.find(result.complexity, "O(N)", 1, true)
          or string.find(result.complexity, "O(N * M)", 1, true)
          or string.find(result.complexity, "O(N log N)", 1, true)
        then
          hl_group = "DjangoORMVirtualTextCrit"
        elseif #result.warnings > 0 then
          hl_group = "DjangoORMVirtualTextWarn"
        end

        vim.api.nvim_buf_set_extmark(0, ns_id, line_num - 1, 0, {
          virt_text = { { vt_text, hl_group } },
          virt_text_pos = "eol",
        })
      end

      -- Build editor diagnostics
      if config.diagnostics.enabled and #result.warnings > 0 then
        local diag_message = "Database warnings:\n"
        for _, w in ipairs(result.warnings) do
          diag_message = diag_message .. "• " .. w .. "\n"
        end
        if #result.suggestions > 0 then
          diag_message = diag_message .. "\nSuggestions:\n"
          for _, s in ipairs(result.suggestions) do
            diag_message = diag_message .. "💡 " .. s .. "\n"
          end
        end

        local diag = {
          bufnr = 0,
          lnum = line_num - 1,
          col = 0,
          end_lnum = line_num - 1,
          end_col = -1,
          severity = vim.diagnostic.severity.WARN,
          source = "Django ORM",
          message = diag_message,
        }
        vim.diagnostic.set(ns_id, 0, { diag })
      end

      -- Display floating analysis window
      local ui = require("django-orm-analyzer.ui")
      ui.show_panel(result, query_str)
    end,
  })
end

return M
