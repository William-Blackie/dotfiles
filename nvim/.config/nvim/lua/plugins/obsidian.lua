return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  cmd = "Obsidian",
  ft = "markdown",
  keys = {
    {
      "<leader>n",
      group = "Notes",
    },
    {
      "<leader>nn",
      "<CMD>Obsidian quick_switch<CR>",
      desc = "Notes Quick Switch",
    },
    {
      "<leader>nN",
      "<CMD>Obsidian new<CR>",
      desc = "Notes New",
    },
    {
      "<leader>nf",
      "<CMD>Obsidian search<CR>",
      desc = "Notes Search",
    },
    {
      "<leader>nd",
      "<CMD>Obsidian today<CR>",
      desc = "Notes Today",
    },
    {
      "<leader>nD",
      "<CMD>Obsidian dailies<CR>",
      desc = "Notes Dailies",
    },
    {
      "<leader>nb",
      "<CMD>Obsidian backlinks<CR>",
      desc = "Notes Backlinks",
    },
    {
      "<leader>nt",
      "<CMD>Obsidian template<CR>",
      desc = "Notes Template",
    },
    {
      "<leader>no",
      "<CMD>Obsidian open<CR>",
      desc = "Notes Open App",
    },
  },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,
    picker = {
      name = "fzf-lua",
    },
    workspaces = {
      {
        name = "notes",
        path = "~/Obsidian",
      },
      {
        name = "personal",
        path = "~/Obsidian/Personal/",
      },
      {
        name = "work",
        path = "~/Obsidian/Work - Mabyduck/",
      },
    },
  },
}
