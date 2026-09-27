-- [[ Dev Containers ]]
-- Project manifests own images, tools, users, and mounts.
-- Neovim stays on the host; devcontainers.nvim starts LSP servers through the devcontainer CLI.
-- It detects .devcontainer/ at the LSP root; a lone .devcontainer.json is not detected.
-- Docker is required only for container workspaces; images supply their language servers on PATH.
-- <leader>Du starts the project container; <leader>DL opens the integration log.
-- :DevcontainersExec <argv> runs a command in the container rooted at the current cwd.
-- Formatters, build tasks, and DAP remain host-side; Mason installs host tools only.

local project = require 'aakash.project'

return {
    {
        'jedrzejboczar/devcontainers.nvim',
        dependencies = { 'miversen33/netman.nvim' },
        -- Load before FileType starts clients, not from inside an LSP cmd callback.
        lazy = false,
        keys = {
            {
                '<leader>Du',
                function()
                    local root = project.get()
                    if vim.fn.getcwd() ~= root and not project.set(root, false) then return end
                    vim.cmd.DevcontainersUp()
                end,
                desc = 'Devcontainer LSP: [U]p',
            },
            { '<leader>DL', '<cmd>DevcontainersLog<CR>', desc = 'Devcontainer LSP: [L]og' },
        },
        opts = {},
        config = function(_, opts)
            require('devcontainers').setup(opts)
            -- Upstream sets nomodifiable before Netman can populate docker:// buffers.
            -- readonly prevents accidental writes without blocking the file loader.
            vim.api.nvim_clear_autocmds { group = 'devcontainers', event = 'BufAdd', pattern = 'docker://*' }
            vim.api.nvim_create_autocmd('BufAdd', {
                group = 'devcontainers',
                pattern = 'docker://*',
                callback = function(event) vim.bo[event.buf].readonly = true end,
            })
        end,
    },
    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>D', group = '[D]ev Containers' })
        end,
    },
}
