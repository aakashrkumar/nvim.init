-- [[ Formatting ]]
-- Conform owns formatter execution. Language modules add filetypes and save
-- policies through these options; :ConformInfo explains which formatter runs.

return {
    {
        'stevearc/conform.nvim',
        -- Conform documents `BufWritePre` for format-on-save, `ConformInfo` for
        -- inspection, and `keys` for an on-demand mapping. Each trigger also makes
        -- the plugin available on the first use that needs it.
        event = { 'BufWritePre' },
        cmd = { 'ConformInfo' },
        keys = {
            {
                '<leader>f',
                function() require('conform').format { async = true } end,
                mode = { 'n', 'v' },
                desc = '[F]ormat buffer or selection',
            },
        },
        opts = {
            -- [[ Formatting ]]
            notify_on_error = true,
            -- Language modules add filetype keys, so save policies merge in any import order.
            format_on_save_by_ft = {
                lua = { timeout_ms = 1000 },
            },
            default_format_opts = {
                lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to 'never' to disable LSP formatting entirely.
            },
            -- You can also specify external formatters in here.
            formatters_by_ft = {
                lua = { 'stylua' },
                -- You can use 'stop_after_first' to run the first available formatter from the list
                -- javascript = { "prettierd", "prettier", stop_after_first = true },
            },
            formatters = {
                stylua = {
                    append_args = function(_, ctx)
                        if vim.fs.root(ctx.buf, { '.stylua.toml', 'stylua.toml' }) then return {} end
                        -- Without a project style, follow the editor (including EditorConfig).
                        local bo = vim.bo[ctx.buf]
                        local width = bo.shiftwidth == 0 and bo.tabstop or bo.shiftwidth
                        return { '--indent-type', bo.expandtab and 'Spaces' or 'Tabs', '--indent-width', tostring(width) }
                    end,
                },
            },
        },
        config = function(_, opts)
            local format_on_save_by_ft = opts.format_on_save_by_ft
            opts.format_on_save_by_ft = nil
            opts.format_on_save = function(bufnr)
                local rule = format_on_save_by_ft[vim.bo[bufnr].filetype]
                if type(rule) == 'function' then return rule(bufnr) end
                return rule
            end
            require('conform').setup(opts)
        end,
    },
}
