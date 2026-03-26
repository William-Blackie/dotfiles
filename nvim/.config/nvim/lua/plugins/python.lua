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
}
