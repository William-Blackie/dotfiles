-- https://github.com/folke/snacks.nvim
---@type LazyPluginSpec[]
local function resume_gh_review()
  local active = Snacks.picker.get({ source = "gh_diff" })
  local picker = active[#active]
  local resume = require("snacks.picker.resume")
  local state = resume.state.gh_diff
  local opts = picker and picker.opts or state and state.opts
  if not opts or not opts.pr then
    Snacks.picker.gh_pr()
    return
  end

  -- Resuming a picker alone reuses cached reviews, including pending comments.
  require("snacks.gh.api").view(function(item)
    if not item then
      return
    end
    vim.schedule(function()
      if picker and not picker.closed then
        picker:refresh()
        picker:focus("list", { show = true })
      else
        resume.resume({ source = "gh_diff" })
      end
    end)
  end, { type = "pr", repo = opts.repo, number = opts.pr }, { force = true })
end

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    keys = {
      {
        "<leader>gR",
        function()
          Snacks.picker.gh_pr({ search = "review-requested:@me" })
        end,
        desc = "GitHub PRs Awaiting My Review",
      },
      {
        "<leader>gr",
        resume_gh_review,
        desc = "Refresh / Resume GitHub Review",
      },
      {
        "<leader>gn",
        function()
          Snacks.terminal.open({ "gh", "issue", "create" }, { cwd = LazyVim.root() })
        end,
        desc = "New GitHub Issue",
      },
    },
    opts = {
      dashboard = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      statuscolumn = { enabled = true },
      image = { enabled = true },
      picker = {
        ui_select = true,
        sources = {
          explorer = {
            hidden = true,
          },
          files = {
            hidden = true,
          },
          gh_diff = {
            -- Keep the changed-file list docked while reviewing or editing files.
            auto_close = false,
            jump = { close = false },
            layout = {
              preset = "right",
              hidden = {},
            },
          },
        },
      },
    },
    config = function(_, opts)
      local snacks = require("snacks")
      snacks.setup(opts)
      if snacks.config.input.enabled then
        vim.ui.input = snacks.input.input
      end
      if snacks.config.picker.ui_select then
        vim.ui.select = snacks.picker.select
      end
    end,
  },
}
