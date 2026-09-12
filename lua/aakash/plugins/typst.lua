-- [[ Typst ]]
-- Tinymist joins the shared LSP registry for language services and formatting.
-- typst-preview provides a live browser preview without a second compiler.

return {
    {
        'mason-org/mason-lspconfig.nvim',
        opts = {
            servers = {
                tinymist = {
                    -- Inherit nvim-lspconfig's on_attach for :LspTinymistExportPdf
                    -- and :LspTinymistPinMain. See :help lsp-config.
                    settings = {
                        -- Tinymist bundles typstyle. The shared Conform <leader>f uses its
                        -- LSP fallback; no external formatter or format-on-save is needed.
                        formatterMode = 'typstyle',
                        formatterIndentSize = 4,
                        formatterProseWrap = false,
                        -- Preview stays live without continually writing PDFs to disk.
                        exportPdf = 'never',
                    },
                },
            },
        },
    },

    {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            if not vim.tbl_contains(opts.ensure_installed, 'tinymist') then table.insert(opts.ensure_installed, 'tinymist') end
        end,
    },

    -- [[ Live preview ]]
    {
        'chomosuke/typst-preview.nvim',
        version = '1.*',
        ft = 'typst',
        -- Requires curl, a browser, and Mason's tinymist on PATH. Setup downloads
        -- websocat; :TypstPreviewUpdate refreshes plugin-managed dependencies.
        -- For multi-file documents, open main.typ, pin it with <leader>Tm for the
        -- LSP, and start preview there with <leader>Tp. Included-file edits stay
        -- live. Pinning is session-local; export from the main buffer with Te.
        -- Keep native get_root defaults (TYPST_ROOT, project marker, main's dir)
        -- and native cross-jump/follow-cursor behavior rather than a root registry.
        keys = {
            { '<leader>Tp', '<cmd>TypstPreviewToggle<cr>', ft = 'typst', desc = 'Typst: toggle [P]review' },
            { '<leader>Ts', '<cmd>TypstPreviewStop<cr>', ft = 'typst', desc = 'Typst: [S]top preview' },
            { '<leader>Tv', '<cmd>TypstPreviewSyncCursor<cr>', ft = 'typst', desc = 'Typst: sync pre[V]iew to cursor' },
            { '<leader>Tf', '<cmd>TypstPreviewFollowCursorToggle<cr>', ft = 'typst', desc = 'Typst: toggle [F]ollow cursor' },
            { '<leader>Te', '<cmd>LspTinymistExportPdf<cr>', ft = 'typst', desc = 'Typst: [E]xport PDF' },
            { '<leader>Tm', '<cmd>LspTinymistPinMain<cr>', ft = 'typst', desc = 'Typst: pin current [M]ain' },
        },
        opts = {
            dependencies_bin = {
                -- Reuse Mason's compiler instead of downloading a second Tinymist.
                tinymist = vim.fn.has 'win32' == 1 and 'tinymist.cmd' or 'tinymist',
            },
        },
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>T', group = '[T]ypst' })
        end,
    },
}
