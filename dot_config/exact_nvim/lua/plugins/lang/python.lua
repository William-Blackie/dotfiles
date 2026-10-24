local function pytest_args()
  return { "--log-level", "DEBUG" }
end

local function selected_python()
  local python = require("venv-selector").python()
  assert(python and python ~= "", "No Python selected. Run :VenvSelect")
  return python
end

local function django_root(path)
  local root = path and vim.fs.root(path, { "manage.py" })
  if root and vim.uv.fs_stat(vim.fs.joinpath(root, "build/.env")) then
    return root
  end
end

local function neotest_run_args(tree, args)
  args = args or {}
  local position = tree and tree:data()
  local root = position and django_root(position.path)
  if root then
    args.cwd = root
    if vim.uv.cwd() ~= root then
      vim.cmd.cd(root)
    end
  end
  return args
end

return {
  {
    "jeangiraldoo/codedocs.nvim",
    opts = {
      languages = {
        python = {
          default_style = "Google",
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "ruff", "debugpy" } },
  },
  {
    "nvim-neotest/neotest",
    opts = {
      run = { augment = neotest_run_args },
      adapters = {
        ["neotest-python"] = {
          dap = { justMyCode = false },
          args = pytest_args,
          runner = "pytest",
          python = selected_python,
        },
      },
    },
  },
}
