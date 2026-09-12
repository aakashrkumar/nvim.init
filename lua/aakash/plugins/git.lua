-- [[ Git ]]
-- Gitsigns marks changed lines; Diffview reviews changes across files.
-- See `:help gitsigns` and `:help diffview`.

return {
    -- Customize the gutter signs without replacing Gitsigns' change tracking.
    {
        'lewis6991/gitsigns.nvim',
        opts = {
            signs = {
                add = { text = '+' }, ---@diagnostic disable-line: missing-fields
                change = { text = '~' }, ---@diagnostic disable-line: missing-fields
                delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
                topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
                changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
            },
        },
    },

    -- [[ Diffview+ ]]
    {
        'dlyongemallo/diffview-plus.nvim',
        main = 'diffview',
        cmd = {
            'DiffviewOpen',
            'DiffviewClose',
            'DiffviewToggle',
            'DiffviewFileHistory',
            'DiffviewDiffFiles',
            'DiffviewLog',
        },
        opts = {
            enhanced_diff_hl = true,
        },
        keys = {
            -- Open all local changes compared with HEAD.
            {
                '<leader>gd',
                '<cmd>DiffviewOpen HEAD<CR>',
                desc = 'Git: open [D]iffview',
            },
            {
                '<leader>gc',
                '<cmd>DiffviewClose<CR>',
                desc = 'Git: [C]lose Diffview',
            },
        },
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>g', group = '[G]it' })

            -- Enable this group if the recommended Gitsigns mappings are moved out of
            -- `_examples` and into the active configuration.
            -- table.insert(opts.spec, { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } })
        end,
    },
}
