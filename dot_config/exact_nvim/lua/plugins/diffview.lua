-- The diff cookbook workflow, using LazyVim's Git keymap group.
local function compare_branch(remote)
  local root = vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
  for _, name in ipairs({ "main", "master" }) do
    local branch = remote and ("origin/" .. name) or name
    local ref = remote and ("refs/remotes/" .. branch) or ("refs/heads/" .. branch)
    if
      vim.system({ "git", "rev-parse", "--verify", ref }, { cwd = root }):wait().code == 0
    then
      vim.cmd("DiffviewOpen " .. (remote and "HEAD.." or "") .. branch)
      return
    end
  end
  vim.notify(
    "No "
      .. (remote and "origin/main or origin/master" or "main or master")
      .. " branch found",
    vim.log.levels.WARN
  )
end

return {
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      { "<leader>gd", false },
      { "<leader>gD", false },
    },
  },
  {
    "ibhagwan/fzf-lua",
    optional = true,
    keys = { { "<leader>gd", false } },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      {
        "<leader>gd",
        function()
          if require("diffview.lib").get_current_view() then
            vim.cmd.DiffviewClose()
          else
            vim.cmd.DiffviewOpen()
          end
        end,
        desc = "Diffview: Toggle Working Changes",
      },
      {
        "<leader>gD",
        function()
          compare_branch(false)
        end,
        desc = "Diffview: Compare main/master",
      },
      {
        "<leader>gf",
        "<cmd>DiffviewFileHistory --follow %<cr>",
        desc = "Diffview: File History",
      },
      {
        "<leader>gF",
        "<cmd>DiffviewFileHistory<cr>",
        desc = "Diffview: Repository History",
      },
      {
        "<leader>gH",
        "<cmd>.DiffviewFileHistory --follow<cr>",
        desc = "Diffview: Line History",
      },
      {
        "<leader>gH",
        "<Esc><Cmd>'<,'>DiffviewFileHistory --follow<CR>",
        mode = "v",
        desc = "Diffview: Selection History",
      },
      {
        "<leader>gM",
        function()
          compare_branch(true)
        end,
        desc = "Diffview: Compare origin/main/master",
      },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Diffview: Close" },
    },
    opts = {
      hooks = {
        view_leave = function(view)
          -- Keep unsaved edits in memory when Diffview closes their last window,
          -- even with 'nohidden'. This also covers :DiffviewClose directly.
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].modified and vim.bo[buf].buftype == "" then
              vim.bo[buf].bufhidden = "hide"
            end
          end
        end,
      },
      keymaps = {
        view = { { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } } },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
        },
      },
    },
  },
}
