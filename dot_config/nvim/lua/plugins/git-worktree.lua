-- Normalize branch name by removing username and gitflow prefixes
-- e.g., "williamblackie/feature/my-branch" -> "my-branch"
local function normalize_branch_name(branch)
  -- Remove username prefix first (e.g., "williamblackie/")
  local normalized = branch:gsub("^[^/]+/", "")
  -- Then remove gitflow prefix (feature/, bugfix/, release/, hotfix/)
  normalized = normalized:gsub("^[^/]+/", "")
  return normalized
end

return {
  "polarmutex/git-worktree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/snacks.nvim",
  },
  config = function()
    vim.g.git_worktree = {
      confirm_telescope_deletions = true,
      change_directory_command = "cd",
      update_on_change = true,
      update_on_change_command = "e .",
      clearjumps_on_change = true,
      autopush = false,
    }

    -- When switching try to set the TMUX window to current tree.
    -- Clear harpoon too.
    local hooks = require("git-worktree.hooks")
    hooks.register(hooks.type.SWITCH, function(path, prev_path)
      pcall(function()
        require("harpoon"):list():clear()
      end)
      if os.getenv("TMUX") then
        local abs_path = vim.fn.fnamemodify(path, ":p")
        vim.fn.jobstart({
          "tmux",
          "set-window-option",
          "-t",
          ".",
          "default-path",
          abs_path,
        })
      end
      hooks.builtins.update_current_buffer_on_switch(path, prev_path)
    end)

    -- CREATE hook: Set upstream tracking and run make setup after creating a worktree
    hooks.register(hooks.type.CREATE, function(path, branch, upstream)
      -- Set upstream tracking for the new worktree branch
      local upstream_branch = upstream or ("origin/" .. branch)
      local cmd = {
        "git",
        "-C",
        path,
        "branch",
        "--set-upstream-to=" .. upstream_branch,
        branch,
      }
      local result = vim.fn.system(cmd)
      if vim.v.shell_error == 0 then
        vim.notify(
          "Set upstream for '" .. branch .. "' to '" .. upstream_branch .. "'",
          vim.log.levels.INFO
        )
      else
        vim.notify("Failed to set upstream: " .. result, vim.log.levels.WARN)
      end

      -- Run make setup if Makefile exists
      local makefile_path = path .. "/Makefile"
      if vim.fn.filereadable(makefile_path) == 1 then
        vim.notify("Running make setup in " .. path .. "...", vim.log.levels.INFO)
        local make_result = vim.fn.system({ "make", "-C", path, "setup" })
        if vim.v.shell_error == 0 then
          vim.notify("make setup completed successfully", vim.log.levels.INFO)
        else
          vim.notify("make setup failed: " .. make_result, vim.log.levels.ERROR)
        end
      end
    end)
  end,
  keys = {
    {
      "<leader>gwc",
      function()
        local function get_branches()
          local branches = {}
          local handle =
            io.popen("git branch -r --format='%(refname:short)' | grep -v HEAD")
          if handle then
            for line in handle:lines() do
              local branch = line:gsub("origin/", "")
              if branch ~= "origin" and branch ~= "" then
                table.insert(branches, {
                  text = branch,
                  value = branch,
                })
              end
            end
            handle:close()
          end

          -- Add option to create new branch
          table.insert(branches, 1, {
            text = "Create New Branch",
            value = "create_new",
          })
          return branches
        end

        local snacks = require("snacks")
        local branches = get_branches()
        local items = {}
        for _, branch in ipairs(branches) do
          table.insert(items, branch.text)
        end

        snacks.picker.select(items, {
          prompt = "Create Worktree from Branch:",
        }, function(choice)
          if not choice then
            return
          end

          local git_worktree = require("git-worktree")
          if choice == "Create New Branch" then
            -- Create new branch
            local branch = vim.fn.input("New branch name: ")
            if branch and branch ~= "" then
              local git_common_dir =
                vim.fn.systemlist("git rev-parse --git-common-dir")[1]
              local git_root = vim.fn.fnamemodify(git_common_dir, ":h")
              local normalized = normalize_branch_name(branch)
              local default_path = git_root .. "/" .. normalized
              local path = vim.fn.input("Path (default: " .. default_path .. "): ")
              if path == "" then
                path = default_path
              end
              local ok, err =
                pcall(git_worktree.create_worktree, path, branch, "origin/" .. branch)
              if not ok then
                vim.notify(
                  "Failed to create worktree: " .. tostring(err),
                  vim.log.levels.ERROR
                )
              else
                vim.notify("Created worktree: " .. path, vim.log.levels.INFO)
              end
            end
          else
            -- Use existing branch
            local git_common_dir = vim.fn.systemlist("git rev-parse --git-common-dir")[1]
            local git_root = vim.fn.fnamemodify(git_common_dir, ":h")
            local normalized = normalize_branch_name(choice)
            local default_path = git_root .. "/" .. normalized
            local path = vim.fn.input("Path (default: " .. default_path .. "): ")
            if path == "" then
              path = default_path
            end
            local ok, err =
              pcall(git_worktree.create_worktree, path, choice, "origin/" .. choice)
            if not ok then
              vim.notify(
                "Failed to create worktree: " .. tostring(err),
                vim.log.levels.ERROR
              )
            else
              vim.notify("Created worktree: " .. path, vim.log.levels.INFO)
            end
          end
        end)
      end,
      desc = "Create worktree from origin or new branch",
    },
    {
      "<leader>gwp",
      function()
        local function get_worktrees()
          local worktrees = {}
          local handle = io.popen("git worktree list")
          if handle then
            for line in handle:lines() do
              local path = line:match("^([^%s]+)")
              local branch = line:match("%[([^%]]+)%]")
              if path and branch then
                table.insert(worktrees, {
                  text = branch .. " (" .. path .. ")",
                  value = path,
                  branch = branch,
                  path = path,
                })
              end
            end
            handle:close()
          end
          return worktrees
        end

        local snacks = require("snacks")
        local worktrees = get_worktrees()
        local items = {}
        for _, wt in ipairs(worktrees) do
          table.insert(items, wt.text)
        end

        snacks.picker.select(items, {
          prompt = "Switch Git Worktree:",
        }, function(choice)
          if not choice then
            return
          end

          -- Find the worktree that matches the display choice
          for _, wt in ipairs(worktrees) do
            if wt.text == choice then
              local git_worktree = require("git-worktree")
              git_worktree.switch_worktree(wt.value)
              break
            end
          end
        end)
      end,
      desc = "Switch Git Worktree",
    },
    {
      "<leader>gwd",
      function()
        local function get_worktrees()
          local worktrees = {}
          local handle = io.popen("git worktree list")
          if handle then
            for line in handle:lines() do
              local path = line:match("^([^%s]+)")
              local branch = line:match("%[([^%]]+)%]")
              if path and branch and branch ~= "main" and branch ~= "master" then
                table.insert(worktrees, {
                  text = branch .. " (" .. path .. ")",
                  value = path,
                  branch = branch,
                  path = path,
                })
              end
            end
            handle:close()
          end
          return worktrees
        end

        local worktrees = get_worktrees()
        if #worktrees == 0 then
          vim.notify("No worktrees available for deletion", vim.log.levels.INFO)
          return
        end

        local snacks = require("snacks")
        local items = {}
        for _, wt in ipairs(worktrees) do
          table.insert(items, wt.text)
        end

        snacks.picker.select(items, {
          prompt = "Delete Git Worktree:",
        }, function(choice)
          if not choice then
            return
          end

          -- Find the worktree that matches the display choice
          for _, wt in ipairs(worktrees) do
            if wt.text == choice then
              local git_worktree = require("git-worktree")
              git_worktree.delete_worktree(wt.value, false)
              break
            end
          end
        end)
      end,
      desc = "Delete Git Worktree",
    },
    {
      "<leader>gwi",
      function()
        local snacks = require("snacks")

        -- Check if we're in an empty directory or a git repo
        local is_git_repo = vim.fn.isdirectory(".git") == 1
          or vim.fn.filereadable(".git") == 1
        local has_bare = vim.fn.isdirectory(".bare") == 1

        if is_git_repo or has_bare then
          vim.notify(
            "Already in a git repository or bare repo setup",
            vim.log.levels.WARN
          )
          return
        end

        -- Get repository URL
        snacks.input.input({
          prompt = "Repository URL: ",
        }, function(repo_url)
          if not repo_url or repo_url == "" then
            return
          end

          -- Ask if this is a fork
          snacks.picker.select({ "No", "Yes" }, {
            prompt = "Is this a fork?",
          }, function(is_fork)
            local upstream_url = nil
            if is_fork == "Yes" then
              snacks.input.input({
                prompt = "Upstream URL: ",
              }, function(upstream)
                if upstream and upstream ~= "" then
                  upstream_url = upstream
                end
                proceed_with_init(repo_url, upstream_url)
              end)
            else
              proceed_with_init(repo_url, upstream_url)
            end
          end)
        end)

        local function proceed_with_init(repo_url, upstream_url)
          local Notify = vim.notify

          -- Step 1: Clone as bare repository
          Notify("Cloning bare repository...", vim.log.levels.INFO)
          local bare_result =
            vim.fn.system({ "git", "clone", "--bare", repo_url, ".bare" })
          if vim.v.shell_error ~= 0 then
            Notify("Failed to clone bare repo: " .. bare_result, vim.log.levels.ERROR)
            return
          end

          -- Step 2: Create pointer file
          local git_file = io.open(".git", "w")
          if git_file then
            git_file:write("gitdir: ./.bare\n")
            git_file:close()
          end

          -- Step 3: Configure fetch refs
          vim.fn.system({
            "git",
            "config",
            "remote.origin.fetch",
            "+refs/heads/*:refs/remotes/origin/*",
          })

          -- Step 4: Add upstream if fork
          if upstream_url then
            Notify("Adding upstream remote...", vim.log.levels.INFO)
            vim.fn.system({ "git", "remote", "add", "upstream", upstream_url })
            vim.fn.system({ "git", "fetch", "upstream" })
          end

          -- Step 5: Fetch all branches
          Notify("Fetching branches...", vim.log.levels.INFO)
          local fetch_result = vim.fn.system({ "git", "fetch", "origin" })
          if vim.v.shell_error ~= 0 then
            Notify("Failed to fetch: " .. fetch_result, vim.log.levels.ERROR)
            return
          end

          -- Step 6: Determine main branch name (main or master)
          local main_branch = "main"
          local branch_check =
            vim.fn.system("git branch -r | grep -E 'origin/(main|master)' | head -1")
          if branch_check:match("master") then
            main_branch = "master"
          end

          -- Step 7: Create main worktree
          Notify("Creating main worktree...", vim.log.levels.INFO)
          local worktree_result = vim.fn.system({
            "git",
            "worktree",
            "add",
            main_branch,
            main_branch,
          })
          if vim.v.shell_error ~= 0 then
            Notify("Failed to create worktree: " .. worktree_result, vim.log.levels.ERROR)
            return
          end

          -- Step 8: Set upstream tracking
          vim.fn.system({
            "git",
            "-C",
            main_branch,
            "branch",
            "--set-upstream-to=origin/" .. main_branch,
            main_branch,
          })

          Notify(
            "Bare repository setup complete! Main worktree at: " .. main_branch .. "/",
            vim.log.levels.INFO
          )

          -- Ask if user wants to switch to main worktree
          snacks.picker.select({ "Yes", "No" }, {
            prompt = "Switch to main worktree?",
          }, function(choice)
            if choice == "Yes" then
              vim.cmd("cd " .. main_branch)
              vim.cmd("e .")
            end
          end)
        end
      end,
      desc = "Initialize bare repository project",
    },
  },
}
