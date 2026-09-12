local M = {}
local first_update = true
local updating = false
local last_error

-- Direnv owns the environment diff, including restoration and .envrc approval.
function M.update(directory)
  if updating or vim.fn.executable("direnv") ~= 1 then
    return false
  end
  if not directory then
    if vim.bo.buftype ~= "" then
      return false
    end
    local name = vim.api.nvim_buf_get_name(0)
    directory = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  end
  while directory and vim.fn.isdirectory(directory) ~= 1 do
    directory = vim.fs.dirname(directory)
  end
  if not directory then
    return false
  end

  updating = true
  local env = { NVIM_DIRENV = "1", DIRENV_LOG_FORMAT = "" }
  -- Re-evaluate shell-inherited state once so editor-only settings take effect.
  if first_update then
    env.DIRENV_WATCHES = ""
  end
  local result = vim
    .system({ "direnv", "export", "json" }, {
      cwd = directory,
      env = env,
      text = true,
    })
    :wait(5000)
  first_update = false
  updating = false

  if result.code ~= 0 then
    if last_error ~= directory then
      -- Do not echo .envrc output: it may contain environment values.
      vim.notify(
        "Direnv failed in " .. directory .. ". Check direnv status in a terminal.",
        vim.log.levels.WARN
      )
      last_error = directory
    end
  else
    last_error = nil
  end
  -- Even a denied .envrc can return the diff that unloads the previous project.
  if not result.stdout or result.stdout == "" then
    return result.code == 0
  end
  local ok, changes = pcall(vim.json.decode, result.stdout)
  if not ok or type(changes) ~= "table" then
    vim.notify("Direnv returned invalid JSON", vim.log.levels.WARN)
    return false
  end
  for name, value in pairs(changes) do
    if value == vim.NIL then
      vim.env[name] = nil
    else
      vim.env[name] = value
    end
  end
  if next(changes) then
    vim.api.nvim_exec_autocmds(
      "User",
      { pattern = "ProjectEnvChanged", modeline = false }
    )
  end
  return result.code == 0
end

function M.setup()
  local group = vim.api.nvim_create_augroup("project_env", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile", "BufEnter", "FocusGained" }, {
    group = group,
    callback = function()
      M.update()
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      M.update(vim.fn.getcwd())
    end,
  })
  M.update()
end

return M
