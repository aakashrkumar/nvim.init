-- [[ Diagnostic display and views ]]
-- Native display belongs here; project filtering and cached statusline counts
-- live in aakash.diagnostics.

return {
    -- [[ Inline diagnostics ]]
    {
        'rachartier/tiny-inline-diagnostic.nvim',
        event = 'VeryLazy',
        keys = {
            {
                '<leader>td',
                '<cmd>TinyInlineDiag toggle<CR>',
                desc = '[T]oggle inline [D]iagnostics',
            },
        },
        opts = {
            preset = 'modern',
            options = {
                use_icons_from_diagnostic = true,

                show_code = true,
                show_source = false,
                show_related = {
                    enabled = true,
                    max_count = 3,
                },

                show_all_diags_on_cursorline = true,
                severity = {
                    vim.diagnostic.severity.ERROR,
                    vim.diagnostic.severity.WARN,
                    vim.diagnostic.severity.INFO,
                    vim.diagnostic.severity.HINT,
                },

                softwrap = 30,
                overflow = {
                    mode = 'wrap',
                },
                break_line = {
                    enabled = false,
                },

                multilines = {
                    enabled = true,
                    always_show = true,
                    severity = {
                        vim.diagnostic.severity.ERROR,
                    },
                },

                enable_on_insert = false,
                enable_on_select = false,
                override_open_float = true,
            },
        },
    },

    -- Project counters open Trouble; build output remains in quickfix.
    {
        'folke/trouble.nvim',
        cmd = { 'Trouble' },
        -- Configure native display at startup, even while Trouble is unloaded.
        -- Inline messages are rendered by tiny-inline-diagnostic.
        -- See `:help vim.diagnostic.Opts`.
        init = function()
            vim.diagnostic.config {
                update_in_insert = false,
                severity_sort = true,

                float = { border = 'rounded', source = 'if_many' },
                signs = {
                    severity = { min = vim.diagnostic.severity.WARN },
                    text = {
                        [vim.diagnostic.severity.ERROR] = '',
                        [vim.diagnostic.severity.WARN] = '',
                        [vim.diagnostic.severity.INFO] = '',
                        [vim.diagnostic.severity.HINT] = '',
                    },
                },
                underline = { severity = vim.diagnostic.severity.ERROR },

                virtual_text = false,
                virtual_lines = false,

                jump = {
                    on_jump = function(_, bufnr)
                        vim.diagnostic.open_float {
                            bufnr = bufnr,
                            scope = 'cursor',
                            focus = false,
                        }
                    end,
                },
            }
        end,
        opts = {
            modes = {
                project_diagnostics = {
                    mode = 'diagnostics',
                    focus = true,
                    open_no_results = true,
                    warn_no_results = false,
                    max_items = math.huge,
                },
            },
        },
        keys = {
            {
                '<leader>xx',
                function() require('aakash.diagnostics').toggle() end,
                desc = 'Diagnostics: project',
            },
            {
                '<leader>xX',
                '<cmd>Trouble diagnostics toggle filter.buf=0 focus=true<CR>',
                desc = 'Diagnostics: current buffer',
            },
        },
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>x', group = 'Diagnostics' })
        end,
    },
}
