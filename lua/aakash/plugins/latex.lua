-- [[ LaTeX ]]
-- VimTeX owns compilation, viewing, syntax, indentation, and folds.
-- Texlab joins the shared LSP registry for completion, hover, diagnostics, and formatting.

-- [[ Language server ]]
---@type table<string, vim.lsp.Config>
local servers = {
    texlab = {
        -- Keep nvim-lspconfig's tex/plaintex/bib filetypes and native commands.
        settings = {
            texlab = {
                -- Start continuous builds with VimTeX, never a second build-on-save job.
                build = { onSave = false, forwardSearchAfter = false },
                -- Conform's manual <leader>f uses LSP fallback; no prose format-on-save.
                -- Mason supplies standalone latexindent; BibTeX needs no extra tool.
                latexFormatter = 'latexindent',
                bibtexFormatter = 'texlab',
            },
        },
    },
}

return {
    -- [[ Compilation and PDF viewing ]]
    {
        'lervag/vimtex',
        -- VimTeX must own filetype detection from startup, including inverse search.
        lazy = false,
        init = function()
            -- A TeX distribution with latexmk and a PDF viewer is required.
            -- See :help vimtex-compiler-latexmk and :help vimtex-folding.
            vim.g.vimtex_compiler_method = 'latexmk'
            vim.g.vimtex_fold_enabled = 1
            -- Prefer LaTeX motions/text objects over global Tree-sitter/mini mappings.
            -- They stay buffer-local; see :help g:vimtex_mappings_override_existing.
            vim.g.vimtex_mappings_override_existing = 1
            if vim.fn.has 'macunix' == 1 then
                vim.g.vimtex_view_method = 'skim'
                vim.g.vimtex_view_skim_activate = 0 -- Keep focus in Neovim on forward search.
            -- Skim's inverse-search preferences are documented in :help vimtex-view-skim.
            elseif vim.uv.os_uname().sysname == 'Linux' then
                vim.g.vimtex_view_method = 'zathura'
            end
            -- Preserve :help vimtex-default-mappings (localleader is Space here):
            -- <localleader>ll compile, lv view/forward search, lt TOC, le errors, lk stop.
            -- Native environment motions [m/]m and text objects ie/ae remain available.
        end,
    },

    {
        'mason-org/mason-lspconfig.nvim',
        opts = { servers = servers },
    },

    {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            -- Standalone latexindent avoids depending on the system Perl modules.
            for _, tool in ipairs { 'texlab', 'latexindent' } do
                if not vim.tbl_contains(opts.ensure_installed, tool) then table.insert(opts.ensure_installed, tool) end
            end
        end,
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<localleader>l', group = '[L]aTeX', mode = { 'n', 'x' } })
        end,
    },
}
