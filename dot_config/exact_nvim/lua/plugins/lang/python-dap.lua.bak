---@class PythonConfig
---Python testing and debugging configuration

---@class DapConfiguration
---Debug Adapter Protocol configuration
---@field type string Adapter type
---@field request string Request type (launch, attach)
---@field name string Configuration name

---Find Python binary in virtualenv
---@param root? string Project root directory
---@return string Path to Python interpreter
local function python_bin(root)
  local candidates = {
    root and (root .. "/.venv/bin/python") or nil,
    root and (root .. "/venv/bin/python") or nil,
    vim.fn.exepath("python3"),
    vim.fn.exepath("python"),
  }
  for _, c in ipairs(candidates) do
    if c and c ~= "" and vim.fn.executable(c) == 1 then
      return c
    end
  end
  return "python3"
end

---Find manage.py for Django projects
---@return string Path to manage.py
local function manage_py()
  local cwd = vim.uv.cwd()
  local buf = vim.api.nvim_buf_get_name(0)
  local candidates = {
    cwd and (cwd .. "/manage.py") or nil,
    cwd and (cwd .. "/django/manage.py") or nil,
    buf ~= "" and (vim.fs.dirname(buf) .. "/manage.py") or nil,
  }
  for _, c in ipairs(candidates) do
    if c and vim.fn.filereadable(c) == 1 then
      return c
    end
  end
  local roots = {}
  if buf ~= "" then
    table.insert(roots, vim.fs.dirname(buf))
  end
  if cwd and cwd ~= "" then
    table.insert(roots, cwd)
  end
  for _, root in ipairs(roots) do
    local found = vim.fs.find("manage.py", { path = root, upward = true, limit = 1 })[1]
    if found then
      return found
    end
  end
  return "manage.py"
end

---Get Django project root
---@return string Directory path of manage.py
local function django_root()
  return vim.fs.dirname(manage_py())
end

---Find Docker Compose file
---@return string Path to compose file
local function compose_file()
  local root = django_root()
  local files = { root .. "/compose.yaml", root .. "/docker-compose.yml" }
  for _, f in ipairs(files) do
    if vim.fn.filereadable(f) == 1 then
      return f
    end
  end
  return "compose.yaml"
end

---Get Docker binary path
---@return string Path to docker executable
local function docker_bin()
  local p = vim.fn.exepath("docker")
  return p ~= "" and p or "docker"
end

---Get application port
---@return string Port number
local function app_port()
  return vim.env.PORT_APP or "8001"
end

---Port for debugpy listener
---@type number
local debugpy_port = 5678

---Open terminal with command
---@param cmd string Command to run in terminal
local function open_term(cmd)
  vim.cmd("botright split | resize 15 | terminal " .. cmd)
end

---Join shell arguments safely
---@param parts string[] Arguments to join
---@return string Joined shell command
local function shell_join(parts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, parts), " ")
end

---Start Django debug container
local function start_django_debug()
  local base =
    shell_join({ docker_bin(), "compose", "-f", compose_file(), "stop", "django-app" })
  local run = shell_join({
    docker_bin(),
    "compose",
    "-f",
    compose_file(),
    "run",
    "--rm",
    "--publish",
    app_port() .. ":80",
    "--publish",
    "5678:5678",
    "--entrypoint",
    "sh",
    "-e",
    "DJANGO_SETTINGS_MODULE=" .. django_settings_module(),
    "-e",
    "PYDEVD_DISABLE_FILE_VALIDATION=1",
    "django-app",
    "-lc",
    "python -m pip show debugpy >/dev/null 2>&1 || uv pip install --system debugpy && exec python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 ./manage.py runserver 0.0.0.0:80 --noreload",
  })
  open_term("cd " .. vim.fn.shellescape(django_root()) .. " && " .. base .. " && " .. run)
end

---Restore Django app container
local function restore_django_app()
  local cmd = shell_join({
    docker_bin(),
    "compose",
    "-f",
    compose_file(),
    "up",
    "-d",
    "django-app",
  })
  open_term("cd " .. vim.fn.shellescape(django_root()) .. " && " .. cmd)
end

---Check if debugpy is listening on port
---@return boolean True if debugpy is listening
local function debugpy_listening()
  vim.fn.system({ "lsof", "-nP", "-iTCP:" .. debugpy_port, "-sTCP:LISTEN" })
  return vim.v.shell_error == 0
end

---Run Django debug attach configuration
local function run_django_attach()
  ---@type DapConfiguration
  require("dap").run({
    type = "python",
    request = "attach",
    name = "Django: attach docker",
    connect = { host = "127.0.0.1", port = debugpy_port },
    pathMappings = { { localRoot = django_root(), remoteRoot = docker_remote_root() } },
    justMyCode = false,
  })
end

---Wait for Django debug container to start
---@param attempt? number Current attempt count
local function wait_for_django_debug(attempt)
  attempt = attempt or 1
  if debugpy_listening() then
    run_django_attach()
    return
  end
  if attempt >= 60 then
    vim.notify(
      "debugpy did not start on 127.0.0.1:" .. debugpy_port,
      vim.log.levels.ERROR
    )
    return
  end
  vim.defer_fn(function()
    wait_for_django_debug(attempt + 1)
  end, 500)
end

---Attach to Django debug container
local function attach_django_debug()
  if debugpy_listening() then
    run_django_attach()
    return
  end
  vim.notify("Starting Django debug container...", vim.log.levels.INFO)
  start_django_debug()
  wait_for_django_debug()
end

---@type LazyPluginSpec
return {
  ---Python test adapter (forked for Docker support)
  ---@see https://github.com/William-Blackie/neotest-python.git
  {
    "nvim-neotest/neotest-python",
    url = "https://github.com/William-Blackie/neotest-python.git",
    branch = "williamblackie/docker-path-mappings",
  },
  ---Test runner
  ---@see https://github.com/nvim-neotest/neotest
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = { ["neotest-python"] = { runner = "pytest", python = python_bin } },
    },
  },
  ---Debug adapter
  ---@see https://github.com/mfussenegger/nvim-dap
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
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
        "<leader>da",
        function()
          attach_django_debug()
        end,
        desc = "Attach Django Docker",
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
        desc = "Toggle Dap UI",
      },
      {
        "<leader>ds",
        function()
          start_django_debug()
        end,
        desc = "Start Django Debug Container",
      },
      {
        "<leader>dR",
        function()
          restore_django_app()
        end,
        desc = "Restore Django Container",
      },
      {
        "<leader>dt",
        function()
          require("dap-python").test_method()
        end,
        desc = "Debug Test Method",
      },
      {
        "<leader>dT",
        function()
          require("dap-python").test_class()
        end,
        desc = "Debug Test Class",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      require("nvim-dap-virtual-text").setup()
      dap.listeners.on_config["django_debug_auto_start"] = function(config)
        if config.name == "Django: attach docker" and not debugpy_listening() then
          vim.schedule(attach_django_debug)
          config.type = dap.ABORT
          return config
        end
        return config
      end
      ---@type DapConfiguration[]
      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Python: current file",
          program = "${file}",
          python = function()
            return python_bin(django_root())
          end,
          console = "integratedTerminal",
          justMyCode = false,
        },
        {
          type = "python",
          request = "launch",
          name = "Django: runserver",
          program = manage_py,
          cwd = django_root,
          args = { "runserver", "0.0.0.0:8000" },
          python = function()
            return python_bin(django_root())
          end,
          django = true,
          console = "integratedTerminal",
          justMyCode = false,
          env = { DJANGO_SETTINGS_MODULE = django_settings_module() },
        },
        {
          type = "python",
          request = "attach",
          name = "Django: attach docker",
          connect = { host = "127.0.0.1", port = 5678 },
          pathMappings = {
            { localRoot = django_root, remoteRoot = docker_remote_root() },
          },
          justMyCode = false,
        },
      }
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
