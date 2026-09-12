-- Markdown plugins own rendering, structural commands, and vault integration.
-- Source-buffer writing options and motions live in after/ftplugin/markdown.lua.
local obsidian_vault = vim.fn.expand '~/Documents/Notes/Main'

return {
    -- [[ Markdown rendering ]]
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = {
            'nvim-treesitter/nvim-treesitter',
            'nvim-mini/mini.nvim',
        },
        config = function()
            -- Keep the document rendered while writing. Anti-conceal reveals the
            -- Markdown source on the active line without reflowing nearby blocks.
            require('render-markdown').setup {
                render_modes = { 'n', 'i', 'c' },
                anti_conceal = {
                    above = 0,
                    below = 0,
                    ignore = {
                        code_background = true,
                        code_border = true,
                        head_background = true,
                        head_border = true,
                        indent = true,
                        quote = true,
                        sign = true,
                        table_border = true,
                        virtual_lines = true,
                    },
                },
                -- Documentation is read, not edited. Keep scratch Markdown rendered
                -- while focusing or selecting text, without code-language badges.
                overrides = {
                    buftype = {
                        nofile = {
                            anti_conceal = { enabled = false },
                            code = { language = false },
                            win_options = {
                                concealcursor = { rendered = 'nvic' },
                            },
                        },
                    },
                },
                -- Snacks.image owns graphical LaTeX rendering.
                latex = { enabled = false },

                -- Provide checkbox and callout completion through blink.cmp.
                completions = {
                    lsp = { enabled = true },
                },
            }

            vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', {
                desc = '[T]oggle [M]arkdown rendering',
            })
        end,
    },

    -- [[ Structural Markdown editing ]]
    -- Keep MD* command mappings beside the plugin that implements them.
    -- See :help markdown.config.on_attach for buffer-local customization.
    {
        'tadmccorkle/markdown.nvim',
        ft = 'markdown',
        opts = {
            on_attach = function(bufnr)
                local function map(mode, lhs, rhs, desc, opts)
                    opts = vim.tbl_extend('force', {
                        buffer = bufnr,
                        silent = true,
                        desc = desc,
                    }, opts or {})
                    vim.keymap.set(mode, lhs, rhs, opts)
                end

                map('n', '<leader>mx', '<cmd>MDTaskToggle<CR>', 'Markdown: toggle task')
                map('x', '<leader>mx', ':MDTaskToggle<CR>', 'Markdown: toggle selected tasks')
                map('n', '<leader>mo', '<cmd>MDListItemBelow<CR>', 'Markdown: list item below')
                map('n', '<leader>mO', '<cmd>MDListItemAbove<CR>', 'Markdown: list item above')
                map('n', '<leader>mc', '<cmd>MDToc<CR>', 'Markdown: show table of contents')
            end,
        },
    },

    -- [[ Obsidian vault ]]
    -- Vault-aware navigation and note creation complement generic Markdown tools.
    {
        'obsidian-nvim/obsidian.nvim',
        version = '*',
        lazy = false,
        -- Keep vault integration unloaded on machines without this directory.
        cond = vim.fn.isdirectory(obsidian_vault) == 1,
        keys = {
            { '<leader>oq', '<cmd>Obsidian quick_switch<CR>', desc = '[O]bsidian: [Q]uick switch' },
            { '<leader>os', '<cmd>Obsidian search<CR>', desc = '[O]bsidian: [S]earch vault' },
            { '<leader>ot', '<cmd>Obsidian today<CR>', desc = '[O]bsidian: [T]oday' },
            { '<leader>on', '<cmd>Obsidian new<CR>', desc = '[O]bsidian: [N]ew note' },
            { '<leader>ob', '<cmd>Obsidian backlinks<CR>', desc = '[O]bsidian: [B]acklinks' },
            { '<leader>oo', '<cmd>Obsidian open<CR>', desc = '[O]bsidian: [O]pen in app' },
        },
        opts = {
            legacy_commands = false,
            workspaces = {
                {
                    name = 'main',
                    path = obsidian_vault,
                },
            },
            notes_subdir = '010.Inbox',
            new_notes_location = 'notes_subdir',
            note_id_func = function(title)
                local trimmed_title = title and vim.trim(title)
                if trimmed_title and trimmed_title ~= '' then return trimmed_title end
                return require('obsidian.builtin').zettel_id()
            end,
            picker = {
                name = 'snacks.picker',
            },
            templates = {
                folder = 'Settings/Templates',
            },
            daily_notes = {
                folder = '100.Daily',
                template = 'New Daily Note.md',
                default_tags = {},
                workdays_only = false,
            },
            attachments = {
                folder = '700.Resources/709.Attachments',
            },
            frontmatter = {
                enabled = false,
            },
            ui = {
                enable = false,
            },
            footer = {
                enabled = false,
            },
            statusline = {
                enabled = false,
            },
        },
    },

    -- [[ Keymap groups ]]
    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>m', group = '[M]arkdown' })
            table.insert(opts.spec, { '<leader>o', group = '[O]bsidian' })
        end,
    },
}
