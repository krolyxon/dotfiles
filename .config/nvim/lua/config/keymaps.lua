-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
map("n", "<C-n>", "<cmd>NvimTreeToggle<Cr>", { desc = "NvimTree", remap = true })

-- Disable Ctrl+J in insert mode (make it do nothing)
vim.keymap.set("i", "<C-j>", "<Nop>", { noremap = true, silent = true })


vim.keymap.set("n", "<Up>", "<c-w>k")
vim.keymap.set("n", "<Down>", "<c-w>j")
vim.keymap.set("n", "<Left>", "<c-w>h")
vim.keymap.set("n", "<Right>", "<c-w>l")
