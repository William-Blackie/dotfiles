local function python_bin(root)
  local candidates = {
    root and (root .. "/.venv/bin/python") or nil,
    root and (root .. "/venv/bin/python") or nil,
    vim.fn.exepath("python3"),
    vim.fn.exepath("python"),
  }

  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" and vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  return "python3"
end

local function manage_py()
  local cwd = vim.uv.cwd()
  local candidates = {
    cwd and (cwd .. "/manage.py") or nil,
    cwd and (cwd .. "/django/manage.py") or nil,
  }

  local buf = vim.api.nvim_buf_get_name(0)
  if buf ~= "" then
    table.insert(candidates, vim.fs.dirname(buf) .. "/manage.py")
  end

  for _, candidate in ipairs(candidates) do
    if candidate and vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  local search_roots = {}
  if buf ~= "" then
    table.insert(search_roots, vim.fs.dirname(buf))
  end
  if cwd and cwd ~= "" then
    table.insert(search_roots, cwd)
  end

  for _, root in ipairs(search_roots) do
    local found = vim.fs.find("manage.py", { path = root, upward = true, limit = 1 })[1]
    if found then
      return found
    end
  end

  return "manage.py"
end

local function django_root()
  return vim.fs.dirname(manage_py())
end

local function compose_file()
  local root = django_root()
  local candidates = {
    root and (root .. "/compose.yaml") or nil,
    root and (root .. "/docker-compose.yml") or nil,
  }

  for _, candidate in ipairs(candidates) do
    if candidate and vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  return "compose.yaml"
end

local function docker_bin()
  return vim.fn.exepath("docker") ~= "" and vim.fn.exepath("docker") or "docker"
end

local function app_port()
  return vim.env.PORT_APP or "8001"
end

local function open_term(cmd)
  vim.cmd("botright split")
  vim.cmd("resize 15")
  vim.cmd("terminal " .. cmd)
end

local function shell_join(parts)
  return table.concat(vim.tbl_map(vim.fn.shellescape, parts), " ")
end

local function start_django_debug()
  local base = shell_join({
    docker_bin(),
    "compose",
    "-f",
    compose_file(),
    "stop",
    "django-app",
  })
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
      "DJANGO_SETTINGS_MODULE=sites.app.settings.prod",
      "-e",
      "PYDEVD_DISABLE_FILE_VALIDATION=1",
      "django-app",
      "-lc",
      "python -m pip show debugpy >/dev/null 2>&1 || uv pip install --system debugpy && exec python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 ./manage.py runserver 0.0.0.0:80 --noreload",
    })

  open_term("cd " .. vim.fn.shellescape(django_root()) .. " && " .. base .. " && " .. run)
end

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

local function attach_django_debug()
  local dap = require("dap")

  dap.run({
    type = "python",
    request = "attach",
    name = "Django: attach docker",
    connect = { host = "127.0.0.1", port = 5678 },
    pathMappings = {
      {
        localRoot = django_root(),
        remoteRoot = "/www/mabyduck/django",
      },
    },
    justMyCode = false,
  })
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        python = { "ruff_fix", "ruff_organize_imports", "ruff_format" },
      },
    },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          cwd = function(root)
            return root
          end,
          python = python_bin,
        },
      },
    },
  },
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
          require("dapui").toggle({})
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
          env = {
            DJANGO_SETTINGS_MODULE = "sites.app.settings.prod",
          },
        },
        {
          type = "python",
          request = "attach",
          name = "Django: attach docker",
          connect = { host = "127.0.0.1", port = 5678 },
          pathMappings = {
            {
              localRoot = django_root,
              remoteRoot = "/www/mabyduck/django",
            },
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

      vim.api.nvim_create_user_command("DjangoDebugStart", start_django_debug, {})
      vim.api.nvim_create_user_command("DjangoDebugAttach", attach_django_debug, {})
      vim.api.nvim_create_user_command("DjangoDebugRestore", restore_django_app, {})
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "python") then
        table.insert(opts.ensure_installed, "python")
      end
    end,
  },
}
