return {
    -- [[ Editing tools ]]
    -- lazy.nvim's `opts` calls a plugin's setup function with that table.
    -- Use `config` when setup also needs mappings or several Mini modules.

    -- [[ Todo comments ]]
    -- Highlight todo-style comments and search them through Snacks Picker.
    {
        'folke/todo-comments.nvim',
        -- `keys` would normally make this plugin lazy. Keep highlighting active
        -- immediately and use the mappings only as picker entry points.
        lazy = false,
        dependencies = {
            'folke/snacks.nvim',
            'nvim-lua/plenary.nvim',
        },
        keys = {
            {
                '<leader>st',
                function() Snacks.picker.todo_comments() end,
                desc = '[S]earch [T]odo comments',
            },
            {
                '<leader>sT',
                function() Snacks.picker.todo_comments { keywords = { 'TODO', 'FIX', 'FIXME' } } end,
                desc = '[S]earch [T]odo/Fix/Fixme',
            },
        },
        opts = { signs = false },
    },

    -- [[ Mini.nvim ]]
    -- One config owns these small, independent editing and navigation modules.
    {
        'nvim-mini/mini.nvim',
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        },
        config = function()
            local project = require 'aakash.project'

            -- If a nerd font is available, load the icons module for pretty icons in various plugins.
            if vim.g.have_nerd_font then
                require('mini.icons').setup()
                -- Expose MiniIcons through the compatibility API for plugins that still expect `nvim-web-devicons`.
                MiniIcons.mock_nvim_web_devicons()
            end

            -- [[ Text objects ]]
            --
            -- Examples:
            --  - va)  - [V]isually select [A]round [)]paren
            --  - yiNq - [Y]ank [I]nside [N]ext [Q]uote
            --  - ci'  - [C]hange [I]nside [']quote

            -- See :help MiniAi-builtin-textobjects for the complete set.
            local ai = require 'mini.ai'
            require('mini.ai').setup {
                -- Preserve native an/in incremental selection (Neovim>=0.12) and the aa argument textobject.
                -- See `:help treesitter-incremental-selection`.
                mappings = {
                    around_next = 'aN',
                    inside_next = 'iN',
                },
                n_lines = 500,
                custom_textobjects = {
                    o = ai.gen_spec.treesitter {
                        a = {
                            '@block.outer',
                            '@conditional.outer',
                            '@loop.outer',
                        },
                        i = {
                            '@block.inner',
                            '@conditional.inner',
                            '@loop.inner',
                        },
                    },

                    -- Around/inside a function definition.
                    f = ai.gen_spec.treesitter {
                        a = '@function.outer',
                        i = '@function.inner',
                    },

                    -- Around/inside a class, struct, impl, or equivalent language construct.
                    c = ai.gen_spec.treesitter {
                        a = '@class.outer',
                        i = '@class.inner',
                    },

                    -- Mini.ai normally uses `f` for a function call. Since `f` now means
                    -- function definition, preserve function-call text objects under `u`,
                    -- matching LazyVim's convention: "usage".
                    u = ai.gen_spec.function_call(),

                    -- Function call without including a dotted receiver.
                    U = ai.gen_spec.function_call {
                        name_pattern = '[%w_]',
                    },
                },
            }

            -- [[ Surroundings ]]
            --
            -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
            -- - sd'   - [S]urround [D]elete [']quotes
            -- - sr)'  - [S]urround [R]eplace [)] [']
            require('mini.surround').setup()

            require('aakash.statusline').setup()

            -- [[ File navigation ]]
            -- MiniFiles natively notifies LSP servers before/after file operations.
            -- Keep that path enabled; adding a rename autocmd would notify them twice.
            require('mini.files').setup {
                windows = { preview = true, width_preview = 40 },
                options = { permanent_delete = false },
            }

            vim.keymap.set('n', '-', function()
                local file = vim.api.nvim_buf_get_name(0)
                MiniFiles.open(file ~= '' and file or nil)
            end, { desc = 'File explorer (at current file)' })

            vim.keymap.set('n', '<leader>e', function() MiniFiles.open(project.get()) end, { desc = 'File [E]xplorer (project root)' })

            -- [[ Structural editing ]]
            require('mini.pairs').setup()
            require('mini.bracketed').setup {
                -- Keep native diff, word-reference, and persistent yank-history navigation.
                comment = { suffix = '' },
                window = { suffix = '' },
                yank = { suffix = '' },
            }
            require('mini.splitjoin').setup()
            require('mini.align').setup()

            -- [[ Recently visited files ]]
            local visits = require 'mini.visits'
            visits.setup()
            vim.keymap.set('n', '<leader>sv', function() visits.select_path(project.get()) end, { desc = '[S]earch [V]isited files' })
            -- See :help MiniVisits for filtering and sorting visit history.
        end,
    },

    -- [[ Increment and decrement ]]
    -- Dial extends <C-a>/<C-x> while keeping normal, visual, and g-prefixed modes.
    {
        'monaqa/dial.nvim',
        config = function()
            local dial_map = require 'dial.map'
            vim.keymap.set('n', '<C-a>', function() dial_map.manipulate('increment', 'normal') end)
            vim.keymap.set('n', '<C-x>', function() dial_map.manipulate('decrement', 'normal') end)
            vim.keymap.set('n', 'g<C-a>', function() dial_map.manipulate('increment', 'gnormal') end)
            vim.keymap.set('n', 'g<C-x>', function() dial_map.manipulate('decrement', 'gnormal') end)
            vim.keymap.set('x', '<C-a>', function() dial_map.manipulate('increment', 'visual') end)
            vim.keymap.set('x', '<C-x>', function() dial_map.manipulate('decrement', 'visual') end)
            vim.keymap.set('x', 'g<C-a>', function() dial_map.manipulate('increment', 'gvisual') end)
            vim.keymap.set('x', 'g<C-x>', function() dial_map.manipulate('decrement', 'gvisual') end)
        end,
    },

    -- [[ Undo history ]]
    {
        'mbbill/undotree',
        cmd = 'UndotreeToggle',
        init = function()
            vim.g.undotree_WindowLayout = 3
            vim.g.undotree_SetFocusWhenToggle = 1
            vim.g.undotree_ShortIndicators = 1
        end,
        keys = {
            {
                '<leader>u',
                '<cmd>UndotreeToggle<CR>',
                silent = true,
                desc = 'Toggle [U]ndo tree',
            },
        },
    },

    -- [[ Vim practice ]]
    {
        'ThePrimeagen/vim-be-good',
        cmd = 'VimBeGood',
    },
}
