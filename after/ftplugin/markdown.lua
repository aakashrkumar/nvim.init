-- [[ Markdown writing ]]
-- Native ftplugins run for the first buffer too, after the built-in defaults.
-- These writing choices do not depend on markdown.nvim; see :help ftplugin-overrule.
-- Hover and plugin previews own their scratch-buffer options and mappings.
if vim.bo.buftype ~= '' then return end

local bufnr = vim.api.nvim_get_current_buf()

-- Visually wrap paragraphs without inserting hard line breaks into the file.
-- See :help 'linebreak' and :help fo-table for display versus formatting options.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove { 't' }

-- Keep spelling diagnostics hidden until explicitly requested.
vim.opt_local.spell = false
vim.opt_local.spelllang = 'en_us'

-- [[ Writing mappings ]]
local function map(mode, lhs, rhs, desc, opts)
    opts = vim.tbl_extend('force', {
        buffer = bufnr,
        silent = true,
        desc = desc,
    }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
end

local function display_line_motion(key)
    return function() return vim.v.count == 0 and 'g' .. key or key end
end

-- Uncounted motions follow wrapped prose; counts still move by logical lines.
-- See :help gj and :help gk.
map({ 'n', 'x' }, 'j', display_line_motion 'j', 'Down by display line', { expr = true })
map({ 'n', 'x' }, 'k', display_line_motion 'k', 'Up by display line', { expr = true })
map('n', '<leader>ts', '<cmd>setlocal spell! spell?<CR>', '[T]oggle [S]pelling')
map('n', '<leader>tw', function() Snacks.zen() end, 'Toggle writing view')

-- [[ Self notes ]]
-- Treesitter clears regex syntax when it starts; add this match afterward.
-- The buffer may close or change filetype before the scheduled callback runs.
vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= 'markdown' or vim.bo[bufnr].buftype ~= '' then return end
    vim.api.nvim_buf_call(bufnr, function()
        -- A filetype reload can leave multiple callbacks queued. Replace our
        -- match rather than adding another copy when those callbacks run.
        vim.cmd 'silent! syntax clear MarkdownSelfNote'
        vim.cmd.syntax [[match MarkdownSelfNote /{[^{}]*}/ contains=@Spell]]
    end)
end)

-- [[ Filetype cleanup ]]
-- Extend the built-in rollback so another filetype inherits none of these
-- local writing choices. See :help undo_ftplugin and :help :setlocal.
-- Keep separators bare: spaces before | become part of an :unmap key.
local undo = table.concat({
    'setlocal wrap< linebreak< breakindent< spell< spelllang< textwidth< formatoptions<',
    'silent! nunmap <buffer> j',
    'silent! xunmap <buffer> j',
    'silent! nunmap <buffer> k',
    'silent! xunmap <buffer> k',
    'silent! nunmap <buffer> <leader>ts',
    'silent! nunmap <buffer> <leader>tw',
    'silent! syntax clear MarkdownSelfNote',
}, '|')
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. '|' .. undo) or undo
