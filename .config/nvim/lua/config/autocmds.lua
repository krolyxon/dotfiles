-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local autocmd = vim.api.nvim_create_autocmd

-- remove trailing whitespaces on :w
autocmd({ "bufwritepre" }, {
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

-- spell check markdown and tex files
vim.cmd([[
  augroup spellCheck
    autocmd!
    autocmd Filetype plaintext setlocal spell
    autocmd FileType markdown setlocal spell
    autocmd BufRead,BufNewFile *.md setlocal spell
    autocmd BufRead,BufNewFile *.rmd setlocal spell
    autocmd BufRead,BufNewFile *.Rmd setlocal spell
    autocmd BufRead,BufNewFile *.tex setlocal spell
  augroup END
]])

local build_commands = {
    c = "!g++ -std=c++17 -o %:p:r.o %",
    cpp = "!g++ -std=c++17 -Wall -O2 -o %:p:r.o %",
    rust = "!cargo build --release",
    go = "!go build",
    -- tex = "pdflatex %",
    tex = "VimtexCompile",
    javascript = "",
    java = "!jrun %",
}

local debug_build_commands = {
    c = "!g++ -std=c++17 -g -o %:p:r.o %",
    cpp = "!g++ -std=c++17 -g -o %:p:r.o %",
    rust = "!cargo build",
    go = "!go build",
}

local run_commands = {
    c = "%:p:r.o",
    cpp = "%:p:r.o",
    rust = "cargo run --release",
    go = "go run .",
    tex = "",
    javascript = "node %",
    python = "python3 %",
}

vim.api.nvim_create_user_command("Build", function()
    local filetype = vim.bo.filetype

    for file, command in pairs(build_commands) do
        if filetype == file then
            vim.cmd(command)
            break
        end
    end
end, {})

vim.api.nvim_create_user_command("DebugBuild", function()
    local filetype = vim.bo.filetype

    for file, command in pairs(debug_build_commands) do
        if filetype == file then
            vim.cmd(command)
            break
        end
    end
end, {})

vim.api.nvim_create_user_command("Run", function()
    local filetype = vim.bo.filetype

    for file, command in pairs(run_commands) do
        if filetype == file then
            vim.cmd("sp") -- Vertical split
            -- vim.cmd("vs") -- Horizontal split
            vim.cmd("term " .. command)
            vim.cmd("resize 20N") -- Comment this if horizontal
            local keys = vim.api.nvim_replace_termcodes("i", true, false, true)
            vim.api.nvim_feedkeys(keys, "n", false)
            break
        end
    end
end, {})

vim.api.nvim_create_user_command("Ha", function()
    vim.cmd([[Build]])
    vim.cmd([[Run]])
end, {})

vim.api.nvim_create_user_command("Config", function()
    vim.cmd([[cd ~/.config/nvim]])
end, {})
