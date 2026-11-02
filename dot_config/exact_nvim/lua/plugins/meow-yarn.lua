-- Expandable call hierarchy tree; gai/gao (Snacks) only show one level.
return {
  {
    "retran/meow.yarn.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    main = "meow.yarn",
    cmd = "MeowYarn",
    keys = {
      { "gaI", "<cmd>MeowYarn call callers<cr>", desc = "Call tree incoming" },
      { "gaO", "<cmd>MeowYarn call callees<cr>", desc = "Call tree outgoing" },
    },
    -- Prefetching loads caller files in parallel; each load makes ty cancel the
    -- in-flight requests ("content modified"), leaving nodes looking empty.
    opts = { expand_depth = 1 },
  },
}
