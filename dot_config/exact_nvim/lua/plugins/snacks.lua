-- https://github.com/folke/snacks.nvim
---@type LazyPluginSpec[]
local function resume_gh_review()
  local active = Snacks.picker.get({ source = "gh_diff" })
  if active[#active] then
    active[#active]:focus("list", { show = true })
    return
  end

  local resume = require("snacks.picker.resume")
  if resume.state.gh_diff then
    resume.resume({ source = "gh_diff" })
    return
  end

  Snacks.notify.warn(
    "No GitHub review to resume. Press Space, then g, then p to open one."
  )
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
        desc = "Resume GitHub Review",
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
              hidden = { "preview" },
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
