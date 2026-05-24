local root_markers = { "manage.py", "pyproject.toml", "pytest.ini", "setup.cfg", ".git" }
local debug_port = tonumber(vim.env.NEOTEST_DOCKER_DEBUG_PORT or "5678")

---@param path string|nil
---@return string|nil
local function resolve(path)
  return path and path ~= "" and vim.fn.resolve(path) or path
end

---@param path string
---@return string
local function project_root(path)
  return vim.fs.root(path, root_markers) or vim.uv.cwd()
end

---@param root string
---@return string|nil
local function compose_file(root)
  local found = vim.fs.find({ "compose.yaml", "compose.yml", "docker-compose.yml" }, {
    path = root,
    upward = true,
    limit = 1,
  })[1]
  return found and resolve(found) or nil
end

---@return string
local function docker_service()
  return vim.env.NEOTEST_DOCKER_SERVICE or "django-app"
end

---@return string
local function docker_root()
  return vim.env.NEOTEST_DOCKER_ROOT or "/app"
end

---@return string
local function docker_python()
  return vim.env.NEOTEST_DOCKER_PYTHON or "python"
end

---@return string
local function host_tmp()
  return resolve(vim.uv.os_tmpdir() or vim.env.TMPDIR or "/tmp")
end

---@return string
local function neotest_python_root()
  local script = vim.api.nvim_get_runtime_file("neotest.py", true)[1]
  return script and resolve(vim.fs.dirname(script)) or ""
end

---@param parts string[]
---@return string
local function shell_join(parts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, parts), " ")
end

---@param root string
---@return string[]
local function docker_prefix(root)
  local cmd = { "docker", "compose" }
  local file = compose_file(root)
  if file then
    vim.list_extend(cmd, { "-f", file })
  end
  return cmd
end

---@param root string
---@return table<string, string>
local function path_mappings(root)
  local mappings = {
    [resolve(root)] = docker_root(),
    [host_tmp()] = "/tmp",
  }

  local plugin_root = neotest_python_root()
  if plugin_root ~= "" then
    mappings[plugin_root] = plugin_root
  end

  return mappings
end

---@param root string
---@param publish_debug_port? boolean
---@return string[]
local function docker_run_prefix(root, publish_debug_port)
  local cmd = docker_prefix(root)
  vim.list_extend(cmd, {
    "run",
    "--rm",
    "-T",
    "-v",
    resolve(root) .. ":" .. docker_root(),
    "-v",
    host_tmp() .. ":/tmp",
    "-w",
    docker_root(),
  })

  local plugin_root = neotest_python_root()
  if plugin_root ~= "" then
    vim.list_extend(cmd, { "-v", plugin_root .. ":" .. plugin_root .. ":ro" })
  end

  if publish_debug_port then
    vim.list_extend(cmd, { "--publish", debug_port .. ":" .. debug_port })
  end

  vim.list_extend(cmd, { "--entrypoint", docker_python(), docker_service() })
  return cmd
end

---@param root string
---@return string[]
local function docker_python_command(root)
  return docker_run_prefix(root, false)
end

---@param context table
local function start_docker_debug(context)
  local cmd = docker_run_prefix(context.root, true)
  vim.list_extend(cmd, {
    "-m",
    "debugpy",
    "--listen",
    "0.0.0.0:" .. debug_port,
    "--wait-for-client",
    context.container_script_path,
  })
  vim.list_extend(cmd, context.script_args)

  vim.cmd("botright split | resize 15 | terminal " .. shell_join(cmd))
end

---@param context table
---@return table
local function docker_attach_config(context)
  start_docker_debug(context)
  return {
    type = "python",
    request = "attach",
    name = "Neotest Docker Debugger",
    connect = { host = "127.0.0.1", port = debug_port },
    pathMappings = {
      { localRoot = resolve(context.root), remoteRoot = docker_root() },
    },
    justMyCode = false,
  }
end

---@type LazyPluginSpec[]
return {
  {
    "nvim-neotest/neotest-python",
    url = "https://github.com/William-Blackie/neotest-python.git",
    branch = "williamblackie/docker-path-mappings",
    dev = true,
  },

  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          root = function(path)
            return project_root(path)
          end,
          python = function(root)
            return docker_python_command(root)
          end,
          path_mappings = function(root)
            return path_mappings(root)
          end,
          dap = function(_, _, _, context)
            return docker_attach_config(context)
          end,
        },
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle DAP UI",
      },
    },
    config = function()
      local dapui = require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      require("dap").listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      require("dap").listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      require("dap").listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
