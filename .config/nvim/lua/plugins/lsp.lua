return {
    {
        "neovim/nvim-lspconfig",
        opts = function(_, opts)
            -- Add your desired LSP server here
            opts.servers.arduino_language_server = {
                cmd = {
                    "arduino-language-server",
                    "-clangd",
                    "/usr/bin/clangd",
                    "-cli",
                    "/usr/bin/arduino-cli",
                    "-cli-config",
                    "/home/krolyxon/.arduino15/arduino-cli.yaml",
                    "-fqbn",
                    "arduino:avr:uno",
                },
            } -- Example: Python

            opts.servers.pyright = {}
            opts.servers.clangd = {}

            -- local servers = { "cssls", "jdtls", "slint_lsp", "pyright", "marksman", "eslint", "tailwindcss", "phpactor", "gopls", "clangd", "arduino_language_server" }
        end,
    },
}
