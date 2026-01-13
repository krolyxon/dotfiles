return {
    -- {
    --     "folke/tokyonight.nvim",
    --     opts = {
    --         transparent = true,
    --         styles = {
    --             sidebars = "transparent",
    --             floats = "transparent",
    --         },
    --     },
    -- },

    "RedsXDD/neopywal.nvim",
    name = "neopywal",
    lazy = false,
    priority = 1000,
    opts = {
        transparent_background = true,
        plugins = {
            alpha = true,
            dashboard = false,
            git_gutter = true,
            indent_blankline = true,
            lazy = true,
            lazygit = true,
            noice = false,
            notify = true,
            nvim_cmp = true,
            mini = {
                hipatterns = true,
                indentscope = {
                    enabled = false,
                },
                pick = true,
                starter = true,
            },
        },
    },

    config = function(_, opts)
        require("neopywal").setup(opts)
        vim.cmd.colorscheme("neopywal")
    end,
}
