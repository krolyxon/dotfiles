return {
    "epwalsh/obsidian.nvim",
    version = "*",  -- recommended, use latest release instead of latest commit
    lazy = false,
    -- ft = "markdown",
    -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
    -- event = {
    --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
    --   -- refer to `:h file-pattern` for more examples
    --   "BufReadPre path/to/my-vault/*.md",
    --   "BufNewFile path/to/my-vault/*.md",
    -- },
    dependencies = {
        -- Required.
        "nvim-lua/plenary.nvim",

        -- see below for full list of optional dependencies 👇
    },
    opts = {
        workspaces = {
            {
                name = "Brain",
                path = "~/dox/brain",
                overrides = {
                    disable_frontmatter = true,
                }
            },
            {
                name = "no-vault",
                path = function()
                    -- alternatively use the CWD:
                    -- return assert(vim.fn.getcwd())
                    return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
                end,
                overrides = {
                    notes_subdir = vim.NIL,  -- have to use 'vim.NIL' instead of 'nil'
                    new_notes_location = "current_dir",
                    templates = {
                        folder = vim.NIL,
                    },
                    disable_frontmatter = true,
                },
            },
        },

        templates = {
            folder = "99 - Meta/Templates",
            date_format = "%Y-%m-%d-%a",
            time_format = "%H:%M",
        },
        -- see below for full list of options 👇
    },
}
