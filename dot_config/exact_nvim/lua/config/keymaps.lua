-- Insert mode navigation
vim.keymap.set("i", "<C-h>", "<Left>", { desc = "Move left" })
vim.keymap.set("i", "<C-l>", "<Right>", { desc = "Move right" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "Move down" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "Move up" })

-- Search and replace word under cursor
vim.keymap.set("n", "gsw", ":%s/<C-r><C-w>/", { desc = "Replace word (global)" })
vim.keymap.set({ "n", "v" }, "gsW", function()
  return ":" .. vim.fn.line(".") .. "s/<C-r><C-w>/ /g<left><left>"
end, { expr = true, desc = "Replace word (line)" })

-- Diagnostics
vim.keymap.set(
  "n",
  "<leader>cd",
  vim.diagnostic.open_float,
  { desc = "Line diagnostics" }
)
vim.keymap.set("n", "<leader>cD", vim.diagnostic.setloclist, { desc = "All diagnostics" })
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Prev diagnostic" })

-- Search results centered
vim.keymap.set("n", "n", "nzzzv", { desc = "Next result" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev result" })
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines" })

-- Buffer navigation
vim.keymap.set("n", "<Tab>", "<CMD>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-Tab>", "<CMD>bprev<CR>", { desc = "Prev buffer" })
vim.keymap.set("n", "<leader>bd", "<CMD>bdelete<CR>", { desc = "Close buffer" })

-- Visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
vim.keymap.set("v", "p", '"_dP', { desc = "Paste without yank" })

-- Terminal
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal" })
vim.keymap.set("t", "<C-]>", "<C-\\><C-n>", { desc = "Exit terminal" })

-- Codedocs apply annotation
vim.keymap.set("n", "gcd", "<cmd>Codedocs<CR>", { desc = "Insert annotation" })

-- nvim-html-css html peaking
vim.keymap.set("n", "<leader>cp", "<cmd>HtmlCssPeek<CR>", { desc = "Peek CSS source" })
