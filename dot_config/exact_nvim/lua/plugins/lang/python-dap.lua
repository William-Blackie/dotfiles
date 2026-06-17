local root_markers = { "manage.py", "pyproject.toml", "pytest.ini", "setup.cfg", ".git" }
local debug_port = tonumber(
  vim.env.NVIM_DAP_DOCKER_DEBUG_PORT or vim.env.NEOTEST_DOCKER_DEBUG_PORT or "5678"
)

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
  return vim.env.NEOTEST_DOCKER_SERVICE or "django-admin"
end

---@return string
local function docker_root()
  return vim.env.NVIM_DAP_DOCKER_ROOT or vim.env.NEOTEST_DOCKER_ROOT or "/app"
end

---@return string
local function docker_python()
  return vim.env.NVIM_DAP_DOCKER_PYTHON or vim.env.NEOTEST_DOCKER_PYTHON or "python"
end

---@param root string
---@param position table|nil
---@return string|nil
local function django_settings_module(root, position)
  local path = position and (position.path or position.id) or ""
  local site = path:match("/sites/([^/]+)/")
  if
    site and vim.fn.filereadable(root .. "/sites/" .. site .. "/settings/test.py") == 1
  then
    return "sites." .. site .. ".settings.test"
  end

  if
    path:find("/oauth2/", 1, true)
    and vim.fn.filereadable(root .. "/sites/app/settings/test.py") == 1
  then
    return "sites.app.settings.test"
  end

  if
    path:find("/extensions/", 1, true)
    and vim.fn.filereadable(root .. "/sites/common/settings/test.py") == 1
  then
    return "sites.common.settings.test"
  end

  return nil
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

---@return string
local function docker_debug_host()
  return vim.env.NVIM_DAP_DOCKER_HOST or "127.0.0.1"
end

---@return string
local function local_debugpy_python()
  return vim.env.NVIM_DAP_PYTHON or vim.env.PYTHON or "python"
end

---@generic T
---@param items T[]
---@param opts table
---@return T|nil
local function select_item(items, opts)
  local co, is_main = coroutine.running()
  assert(co and not is_main, "select_item must run inside a coroutine")

  vim.schedule(function()
    vim.ui.select(items, opts, function(item)
      coroutine.resume(co, item)
    end)
  end)

  return coroutine.yield()
end

---@param key string
---@return string[]
local function load_history(key)
  local file = vim.fn.stdpath("data") .. "/dap_history.json"
  if vim.fn.filereadable(file) == 0 then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  return ok and data and data[key] or {}
end

---@param key string
---@param value string
local function save_history(key, value)
  local file = vim.fn.stdpath("data") .. "/dap_history.json"
  local all = {}
  if vim.fn.filereadable(file) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
    if ok and data then
      all = data
    end
  end
  local list = vim.tbl_filter(function(v)
    return v ~= value
  end, all[key] or {})
  table.insert(list, 1, value)
  all[key] = vim.list_slice(list, 1, 10)
  vim.fn.writefile({ vim.json.encode(all) }, file)
end

---@param key string
---@param prompt string
---@return string|nil
local function select_or_input(key, prompt, default)
  local co, is_main = coroutine.running()
  assert(co and not is_main, "select_or_input must run inside a coroutine")

  local history = load_history(key)
  local NEW = "[Enter new value…]"
  local items = vim.list_extend(vim.deepcopy(history), { NEW })

  vim.schedule(function()
    vim.ui.select(items, { prompt = prompt }, function(choice)
      coroutine.resume(co, choice)
    end)
  end)

  local choice = coroutine.yield()
  if not choice then
    return nil
  end

  if choice ~= NEW then
    save_history(key, choice)
    return choice
  end

  vim.schedule(function()
    vim.ui.input(
      { prompt = prompt .. ": ", default = history[1] or default or "" },
      function(input)
        coroutine.resume(co, input)
      end
    )
  end)

  local input = coroutine.yield()
  if input and input ~= "" then
    save_history(key, input)
    return input
  end

  return nil
end

---@param path string
---@return string
local function without_trailing_slash(path)
  if path == "/" then
    return path
  end
  return (path:gsub("/+$", ""))
end

---@param path string
---@param prefix string
---@return string|nil
local function subpath_suffix(path, prefix)
  path = without_trailing_slash(resolve(path))
  prefix = without_trailing_slash(resolve(prefix))

  if path == prefix then
    return ""
  end

  if vim.startswith(path, prefix .. "/") then
    return path:sub(#prefix + 1)
  end

  return nil
end

---@param root string
---@param mounts table[]|nil
---@return string|nil
local function remote_root_from_mounts(root, mounts)
  local best_source_len = -1
  local best_remote_root = nil

  for _, mount in ipairs(mounts or {}) do
    if mount.Type == "bind" and mount.Source and mount.Destination then
      local suffix = subpath_suffix(root, mount.Source)
      local source_len = #without_trailing_slash(resolve(mount.Source))
      if suffix and source_len > best_source_len then
        best_source_len = source_len
        best_remote_root = without_trailing_slash(mount.Destination) .. suffix
      end
    end
  end

  return best_remote_root
end

---@param container_name string
---@return table|nil
local function inspect_container(container_name)
  local lines = vim.fn.systemlist({ "docker", "inspect", container_name })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local ok, containers = pcall(vim.json.decode, table.concat(lines, "\n"))
  return ok and containers and containers[1] or nil
end

---@param root string
---@param container_name string|nil
---@return string|nil
local function remote_root_from_container(root, container_name)
  if not container_name or container_name == "" then
    return nil
  end

  local container = inspect_container(container_name)
  if not container then
    return nil
  end

  local remote_root = remote_root_from_mounts(root, container.Mounts)
  if remote_root and remote_root ~= "" then
    return remote_root
  end

  local working_dir = container.Config and container.Config.WorkingDir
  if working_dir and working_dir ~= "" and working_dir ~= "/" then
    return working_dir
  end

  return nil
end

---@return string
local function interactive_docker_root(default)
  local env = vim.env.NVIM_DAP_DOCKER_ROOT or vim.env.NEOTEST_DOCKER_ROOT
  if env and env ~= "" then
    return env
  end
  return select_or_input("docker_root", "Container working dir", default)
    or default
    or docker_root()
end

---@return table
local function dap_abort_config()
  return { type = require("dap").ABORT }
end

---@param ports string
---@return number|nil
local function published_debug_port(ports)
  local override = tonumber(vim.env.NVIM_DAP_DOCKER_CONNECT_PORT or "")
  if override then
    return override
  end

  for port in ports:gmatch("[^,]+") do
    local port_text = vim.trim(port)
    local host_port, container_port = port_text:match(":(%d+)%->(%d+)/tcp")
    if tonumber(container_port) == debug_port then
      return tonumber(host_port)
    end
  end

  return nil
end

---@return table[]
local function running_debugpy_containers()
  local lines = vim.fn.systemlist({
    "docker",
    "ps",
    "--format",
    "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}",
  })

  if vim.v.shell_error ~= 0 then
    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
    return {}
  end

  local containers = {}
  for _, line in ipairs(lines) do
    local id, name, image, ports = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t?(.*)$")
    local port = ports and published_debug_port(ports)
    if id and port then
      table.insert(containers, {
        id = id,
        name = name,
        image = image,
        ports = ports,
        connect_port = port,
      })
    end
  end

  return containers
end

---@param root string
---@return string|nil
local function compose_dir(root)
  local file = compose_file(root)
  return file and vim.fs.dirname(file) or nil
end

---@param root string
---@param command string
---@return string[]
local function compose_lines(root, command)
  local dir = compose_dir(root)
  if not dir then
    return {}
  end

  return vim.fn.systemlist({
    "sh",
    "-lc",
    "cd " .. vim.fn.shellescape(dir) .. " && " .. command,
  })
end

---@param root string
---@return string[]
local function compose_services(root)
  local lines = compose_lines(root, "docker compose config --services")
  if vim.v.shell_error ~= 0 then
    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
    return {}
  end

  return vim.tbl_filter(function(line)
    return line ~= ""
  end, lines)
end

---@param root string
---@return string|nil
local function default_debug_command(root)
  local configured = vim.env.NVIM_DAP_DOCKER_DEBUG_COMMAND
  if configured and configured ~= "" then
    return configured
  end

  if vim.fn.filereadable(resolve(root) .. "/manage.py") == 1 then
    return "./manage.py runserver --noreload 0.0.0.0:"
      .. (vim.env.NVIM_DAP_DOCKER_APP_PORT or "80")
  end

  return vim.fn.input("Debug command: ")
end

---@param name string
---@return table|nil
local function running_container_by_name(name)
  local lines = vim.fn.systemlist({
    "docker",
    "ps",
    "--filter",
    "name=^/" .. name .. "$",
    "--format",
    "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}",
  })

  local id, container_name, image, ports = (lines[1] or ""):match(
    "^([^\t]+)\t([^\t]+)\t([^\t]+)\t?(.*)$"
  )
  if not id then
    return nil
  end

  return {
    id = id,
    name = container_name,
    image = image,
    ports = ports,
    connect_port = published_debug_port(ports),
  }
end

---@param root string
---@param service string
---@return table|nil
local function running_compose_service_container(root, service)
  local lines =
    compose_lines(root, shell_join({ "docker", "compose", "ps", "-q", service }))
  if vim.v.shell_error ~= 0 or not lines[1] or lines[1] == "" then
    return nil
  end

  local inspect = vim.fn.systemlist({
    "docker",
    "ps",
    "--filter",
    "id=" .. lines[1],
    "--format",
    "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}",
  })

  local id, container_name, image, ports = (inspect[1] or ""):match(
    "^([^\t]+)\t([^\t]+)\t([^\t]+)\t?(.*)$"
  )
  if not id then
    return nil
  end

  return {
    id = id,
    name = container_name,
    image = image,
    ports = ports,
    connect_port = published_debug_port(ports),
  }
end

---@param root string
---@param service string
local function restore_compose_service(root, service)
  compose_lines(
    root,
    shell_join({
      "docker",
      "compose",
      "up",
      "-d",
      "--force-recreate",
      "--no-deps",
      service,
    })
  )
end

---@param root string
---@param service string
---@return table|nil
local function start_compose_debug_service(root, service)
  local debug_command = default_debug_command(root)
  if not debug_command or debug_command == "" then
    return nil
  end

  local file = compose_file(root)
  if not file then
    return nil
  end

  local debug_entrypoint = "exec "
    .. shell_join({
      docker_python(),
      "-Xfrozen_modules=off",
      "-m",
      "debugpy",
      "--listen",
      "0.0.0.0:" .. debug_port,
      "--wait-for-client",
    })
    .. " "
    .. debug_command

  local override = vim.fn.tempname() .. ".json"
  vim.fn.writefile({
    vim.json.encode({
      services = {
        [service] = {
          entrypoint = { "sh", "-lc", debug_entrypoint },
          ports = { "127.0.0.1::" .. debug_port },
        },
      },
    }),
  }, override)

  local lines = compose_lines(
    root,
    shell_join({
      "docker",
      "compose",
      "-f",
      file,
      "-f",
      override,
      "up",
      "-d",
      "--force-recreate",
      "--no-deps",
      service,
    })
  )
  if vim.v.shell_error ~= 0 then
    vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
    vim.fn.delete(override)
    return nil
  end

  local container
  vim.wait(15000, function()
    container = running_compose_service_container(root, service)
    return container ~= nil and container.connect_port ~= nil
  end, 100)

  if not container then
    vim.notify(
      "Debug service did not publish " .. debug_port .. "/tcp",
      vim.log.levels.ERROR
    )
    vim.fn.delete(override)
    return nil
  end

  vim.wait(1500, function()
    return false
  end, 100)

  container.compose_debug_root = root
  container.compose_debug_service = service
  container.compose_debug_override = override
  return container
end

---@return table
local function compose_debug_config()
  local root = resolve(project_root(vim.api.nvim_buf_get_name(0)))
  local services = compose_services(root)
  if vim.tbl_isempty(services) then
    vim.notify("No docker compose services found", vim.log.levels.WARN)
    return dap_abort_config()
  end

  local service = select_item(services, { prompt = "Docker compose service" })
  if not service then
    return dap_abort_config()
  end

  local container = start_compose_debug_service(root, service)
  if not container then
    return dap_abort_config()
  end
  local remote_root = remote_root_from_container(root, container.name)
    or interactive_docker_root()

  return {
    type = "python",
    request = "attach",
    name = "Docker Compose: " .. service,
    connect = { host = docker_debug_host(), port = container.connect_port },
    mode = "remote",
    cwd = root,
    pathMappings = {
      { localRoot = root, remoteRoot = remote_root },
    },
    justMyCode = false,
    compose_debug_container = container.name,
    compose_debug_root = container.compose_debug_root,
    compose_debug_service = container.compose_debug_service,
    compose_debug_override = container.compose_debug_override,
  }
end

---@return table
local function compose_debug_template()
  return setmetatable({
    name = "Docker Compose: start service under debugpy",
    type = "python",
    request = "attach",
  }, {
    __call = compose_debug_config,
  })
end

---@return table
local function docker_python_attach_config()
  local containers = running_debugpy_containers()
  if vim.tbl_isempty(containers) then
    vim.notify(
      "No running containers publish " .. debug_port .. "/tcp",
      vim.log.levels.WARN
    )
    return dap_abort_config()
  end

  local container = select_item(containers, {
    prompt = "Docker container",
    format_item = function(item)
      return item.name .. " (" .. item.image .. ") " .. item.ports
    end,
  })

  if not container then
    return dap_abort_config()
  end

  local root = resolve(project_root(vim.api.nvim_buf_get_name(0)))
  local remote_root = remote_root_from_container(root, container.name)
    or interactive_docker_root()
  return {
    type = "python",
    request = "attach",
    name = "Docker Python: " .. container.name,
    connect = { host = docker_debug_host(), port = container.connect_port },
    mode = "remote",
    cwd = root,
    pathMappings = {
      { localRoot = root, remoteRoot = remote_root },
    },
    justMyCode = false,
  }
end

---@return table
local function docker_python_attach_template()
  return setmetatable({
    name = "Docker Python: attach to running debugpy container",
    type = "python",
    request = "attach",
  }, {
    __call = docker_python_attach_config,
  })
end

---@return table
local function docker_debug_template()
  if compose_file(project_root(vim.api.nvim_buf_get_name(0))) then
    return compose_debug_template()
  end

  return docker_python_attach_template()
end

---@param context table
local function start_docker_debug(context)
  local cmd = docker_run_prefix(context.root, true)
  vim.list_extend(cmd, {
    "-Xfrozen_modules=off",
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
          args = function(_, position)
            local path = position and (position.path or position.id)
            local root = path and project_root(path) or vim.uv.cwd()
            local settings = django_settings_module(root, position)
            return settings and { "--ds=" .. settings } or {}
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
      {
        "<leader>dD",
        function()
          require("dap").run(docker_debug_template())
        end,
        desc = "Attach Docker Python",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      local python_adapter = dap.adapters.python
      dap.adapters.python = function(callback, config)
        if config.connect then
          callback({
            type = "server",
            host = config.connect.host,
            port = config.connect.port,
            options = {
              max_retries = 30,
              source_filetype = "python",
            },
          })
        elseif type(python_adapter) == "function" then
          python_adapter(callback, config)
        elseif type(python_adapter) == "table" then
          callback(python_adapter)
        else
          callback({
            type = "executable",
            command = local_debugpy_python(),
            args = { "-m", "debugpy.adapter" },
          })
        end
      end

      dap.configurations.python = dap.configurations.python or {}
      table.insert(dap.configurations.python, compose_debug_template())
      table.insert(dap.configurations.python, docker_python_attach_template())

      local function stop_compose_debug_container(session)
        local config = session and session.config
        if config and config.compose_debug_root and config.compose_debug_service then
          restore_compose_service(config.compose_debug_root, config.compose_debug_service)
        end
        if config and config.compose_debug_override then
          vim.fn.delete(config.compose_debug_override)
        end
      end

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.disconnect["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.after.disconnect["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.before.event_terminated["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.after.event_terminated["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.before.event_exited["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.after.event_exited["compose_debug_cleanup"] =
        stop_compose_debug_container
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
