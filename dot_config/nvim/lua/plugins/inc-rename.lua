---Incremental LSP renaming with live preview
---@see https://github.com/smjonas/inc-rename.nvim
---@type LazyPluginSpec
return {
  "smjonas/inc-rename.nvim",
  opts = {
    -- Show preview even when new name is empty
    preview_empty_name = false,
    -- Show "Renamed m instances in n files" message
    show_message = true,
    -- Don't save in commandline history (prevents issues with navigating older entries)
    save_in_cmdline_history = false,
    -- Use snacks.nvim input if available
    input_buffer_type = "snacks",
  },
  keys = {
    {
      "<leader>rn",
      function()
        return ":IncRename " .. vim.fn.expand("<cword>")
      end,
      expr = true,
      desc = "Incremental rename",
    },
    {
      "<leader>rN",
      ":IncRename ",
      desc = "Incremental rename (empty)",
    },
  },
}
