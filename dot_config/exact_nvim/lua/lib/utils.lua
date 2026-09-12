local lib = {}

-- Common Python project root markers - used by LSP, lint, and other tooling
-- to locate the project root via vim.fs.root() / upward search.
lib.python_root_markers = {
  "ty.toml",
  "pyproject.toml",
  "ruff.toml",
  ".ruff.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "manage.py",
  ".git",
}

-- Subset of python_root_markers that uniquely identifies a Django project.
-- Use this when you specifically need a Django project (not just any Python
-- project) - e.g. Django filetype detection, the djls LSP, etc.
lib.django_root_markers = {
  "manage.py",
  "pyproject.toml",
  ".git",
}

-- Get environment variable with default fallback. Treats both nil and empty
-- string as unset (`:h vim.env` only sets vim.env for non-empty values, but
-- `:let $FOO = ''` can still produce an empty entry).
function lib.env_or_default(name, default)
  local value = vim.env[name]
  if value == nil or value == "" then
    return default
  end
  return value
end

-- Top-level directory of the current git repository, or nil if not in one.
function lib.git_root()
  local result = vim
    .system({ "git", "rev-parse", "--show-toplevel" }, { text = true })
    :wait()
  if result.code ~= 0 then
    return nil
  end
  local root = vim.trim(result.stdout)
  if root == "" then
    return nil
  end
  return root
end

-- Get the selected Python interpreter from venv-selector. Do not discover or
-- infer project venvs here; test/debug tooling should use only the active
-- VenvSelect choice.
function lib.get_python_venv()
  local ok, venv = pcall(require, "venv-selector")
  if ok and venv.python() and venv.python() ~= "" then
    return venv.python()
  end
  return "python"
end

function lib.get_django_settings_module()
  return vim.env.DJANGO_SETTINGS_MODULE
end

function lib.get_django_docker_compose_service()
  return vim.env.DJANGO_DOCKER_COMPOSE_SERVICE
end

function lib.get_django_docker_compose_file()
  return vim.env.DJANGO_DOCKER_COMPOSE_FILE
end

return lib
