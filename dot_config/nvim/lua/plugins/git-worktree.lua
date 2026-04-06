return {
  "polarmutex/git-worktree.nvim",
  version = "^2",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  init = function()
    vim.g.git_worktree = {
      update_on_change = true,
      update_on_change_command = "e .",
      clearjumps_on_change = true,
      confirm_telescope_deletions = true,
      autopush = false,
    }
  end,
  keys = {
    {
      "<leader>gwp",
      function()
        require("telescope").extensions.git_worktree.git_worktree()
      end,
      desc = "Worktree Picker",
    },
    {
      "<leader>gwc",
      function()
        require("plugins.chezmoi.lua.git-worktree").create_gitflow_worktree()
      end,
      desc = "Worktree Create (Gitflow)",
    },
    {
      "<leader>gwd",
      function()
        require("telescope").extensions.git_worktree.git_worktrees()
      end,
      desc = "Worktree Delete",
    },
  },
  config = function()
    local hooks = require("git-worktree.hooks")
    require("telescope").load_extension("git_worktree")

    -- Example: Update Harpoon and Tmux when switching worktrees
    hooks.register(hooks.type.SWITCH, function(path, _)
      local ok, harpoon = pcall(require, "harpoon.mark")
      if ok then
        harpoon.clear_all()
      end
      os.execute("tmux send-keys -t . 'cd " .. path .. "' Enter")
      hooks.builtins.update_current_buffer_on_switch(path, _)
    end)
  end,
  -- Minimal gitflow branch naming helper
  create_gitflow_worktree = function()
    local gitflow_types = {
      { name = "feature", prefix = "williamblackie/feat/" },
      { name = "bugfix", prefix = "williamblackie/fix/" },
      { name = "hotfix", prefix = "williamblackie/hotfix/" },
      { name = "release", prefix = "williamblackie/release/" },
      { name = "support", prefix = "williamblackie/support/" },
      { name = "docs", prefix = "williamblackie/docs/" },
      { name = "chore", prefix = "williamblackie/chore/" },
      { name = "refactor", prefix = "williamblackie/refactor/" },
      { name = "test", prefix = "williamblackie/test/" },
      { name = "ci", prefix = "williamblackie/ci/" },
      { name = "build", prefix = "williamblackie/build/" },
      { name = "perf", prefix = "williamblackie/perf/" },
    }

    vim.ui.select(
      vim.tbl_map(function(t)
        return t.name
      end, gitflow_types),
      { prompt = "Gitflow type:" },
      function(type_name)
        if not type_name then
          return
        end
        local type_entry = vim.tbl_filter(function(t)
          return t.name == type_name
        end, gitflow_types)[1]
        vim.ui.input({ prompt = "Branch name (e.g. foo-bar): " }, function(branch_suffix)
          if not branch_suffix or branch_suffix == "" then
            return
          end
          local branch = type_entry.prefix .. branch_suffix:gsub("%s+", "-")
          require("telescope").extensions.git_worktree.create_git_worktree({ branch = branch })
        end)
      end
    )
  end,
}
