-- [[ Language Server Protocol ]]
-- Language servers provide completion, navigation, refactors, and diagnostics.
-- Neovim is the client; Mason installs the external servers and related tools.
-- See :help lsp and :help lsp-vs-treesitter for how these pieces fit together.

-- [[ Shared server defaults ]]
-- Language modules extend this registry through lazy.nvim's merged opts.
-- There is one vim.lsp.config/enable loop below, not a second setup per language.
-- Add general-purpose servers here (for example, gopls = {}); see :help lsp-config.
---@type table<string, vim.lsp.Config>
local servers = {
    -- LazyDev owns LuaJIT, runtime paths, and workspace libraries.
    -- StyLua owns formatting, including projects with their own LuaLS config.
    lua_ls = {
        on_init = function(client) client.server_capabilities.documentFormattingProvider = false end,
        ---@type lspconfig.settings.lua_ls
        settings = {
            Lua = {
                format = { enable = false },
            },
        },
    },
}

-- Mason also installs standalone tools; StyLua is a formatter, not an LSP server.
local ensure_installed = vim.tbl_keys(servers)
vim.list_extend(ensure_installed, {
    'stylua',
})

return {
    {
        'smjonas/inc-rename.nvim',
        lazy = false,
        opts = { input_buffer_type = 'snacks' },
    },

    -- [[ Lua workspace support ]]
    {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
            -- LazyDev applies workspace settings after LSP attachment, including
            -- clients already running when this filetype-loaded plugin starts.
            enabled = function(root_dir)
                if vim.g.lazydev_enabled == false then return false end
                -- Keep Neovim types here, but let external Lua projects own their settings.
                if vim.fs.normalize(root_dir) == vim.fs.normalize(vim.fn.stdpath 'config') then return true end
                return not (vim.uv.fs_stat(root_dir .. '/.luarc.json') or vim.uv.fs_stat(root_dir .. '/.luarc.jsonc'))
            end,
            library = {
                -- Load vim.uv types only when vim.uv is used.
                { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
            },
        },
    },

    -- [[ Server setup and buffer mappings ]]
    {
        'mason-org/mason-lspconfig.nvim',
        dependencies = {
            {
                'mason-org/mason.nvim',
                opts = {},
            },
            {
                'WhoIsSethDaniel/mason-tool-installer.nvim',
                opts = function(_, opts)
                    opts.ensure_installed = opts.ensure_installed or {}
                    -- Append like the language modules so import order cannot erase tools.
                    for _, tool in ipairs(ensure_installed) do
                        if not vim.tbl_contains(opts.ensure_installed, tool) then table.insert(opts.ensure_installed, tool) end
                    end
                end,
            },
            { 'neovim/nvim-lspconfig' },
            {
                -- Useful status updates for LSP.
                'j-hui/fidget.nvim',
                opts = {},
            },
        },
        opts = {
            -- Keep automatic enabling off: the merged registry below owns every server.
            -- Mason still translates names such as lua_ls to lua-language-server.
            automatic_enable = false,
            servers = servers,
        },
        config = function(_, opts)
            local configured_servers = opts.servers or {}
            local mason_opts = vim.tbl_extend('force', {}, opts)
            mason_opts.servers = nil
            require('mason-lspconfig').setup(mason_opts)

            -- Neovim marks its previews before setting their Markdown filetype.
            -- Other plugins' Markdown windows must keep their own highlights.
            vim.api.nvim_create_autocmd('FileType', {
                group = vim.api.nvim_create_augroup('aakash-lsp-documentation', { clear = true }),
                pattern = 'markdown',
                callback = function(event)
                    for _, win in ipairs(vim.fn.win_findbuf(event.buf)) do
                        if vim.w[win].lsp_floating_bufnr then vim.wo[win].winhighlight = 'NormalFloat:LspDocumentation,FloatBorder:LspDocumentationBorder' end
                    end
                end,
            })

            -- Each attached client gets buffer-local mappings. Language-specific
            -- on_attach callbacks can then provide their own actions or hover UI.
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('aakash-lsp-attach', { clear = true }),
                callback = function(event)
                    -- Keep mappings local to this buffer and easy to find in which-key.
                    local map = function(keys, func, desc, mode)
                        mode = mode or 'n'
                        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                    end

                    local client = vim.lsp.get_client_by_id(event.data.client_id)

                    -- Keep ordinary documentation readable without restricting its height.
                    -- Language-specific on_attach callbacks run afterward: C uses
                    -- pretty_hover and Rust keeps Rustaceanvim's actionable hover.
                    if client and client:supports_method('textDocument/hover', event.buf) then
                        map('K', function() vim.lsp.buf.hover { border = 'rounded', max_width = 88 } end, 'Hover documentation (repeat to focus)')
                    end

                    -- Preview a symbol rename before applying it across the project.
                    if client and client:supports_method('textDocument/rename', event.buf) then
                        vim.keymap.set('n', 'grn', function() return ':IncRename ' .. vim.fn.expand '<cword>' end, {
                            buffer = event.buf,
                            desc = 'LSP: [R]e[n]ame',
                            expr = true,
                        })
                    end

                    -- Apply a fix or refactor offered for the cursor position or selection.
                    map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

                    -- Declaration differs from definition: in C, this often opens a header.
                    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

                    -- Inlay hints can displace code, so keep their visibility easy to toggle.
                    if client and client:supports_method('textDocument/inlayHint', event.buf) then
                        map('<leader>th', function()
                            local filter = { bufnr = event.buf }
                            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
                        end, '[T]oggle Inlay [H]ints')
                    end
                end,
            })

            -- Configure and enable the fully merged registry with Neovim's native API.
            -- Inspect installed servers/tools with :Mason; press g? there for help.
            for name, server in pairs(configured_servers) do
                vim.lsp.config(name, server)
                vim.lsp.enable(name)
            end
        end,
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            vim.list_extend(opts.spec, {
                { '<leader>c', group = '[C]ode' },
                { 'gr', group = 'LSP Actions', mode = { 'n' } },
            })
        end,
    },
}
