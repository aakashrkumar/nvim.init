-- [[ Project-aware statusline ]]
-- The Mini.nvim plugin owns setup; this module keeps its renderer together.
-- See :help MiniStatusline.config for sections and highlight groups.
local M = {}

function M.setup()
    local statusline = require 'mini.statusline'
    local diagnostics = require 'aakash.diagnostics'

    statusline.setup {
        use_icons = vim.g.have_nerd_font,
        content = {
            active = function()
                local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
                local git = statusline.section_git { trunc_width = 40 }
                local diff = statusline.section_diff { trunc_width = 75 }
                local lsp = statusline.section_lsp { trunc_width = 75 }
                local filename = statusline.section_filename { trunc_width = 140 }
                local fileinfo = not statusline.is_truncated(100) and statusline.section_fileinfo { trunc_width = 120 } or ''
                -- Keep compact LINE:COLUMN output without replacing Mini's API.
                local location = '%2l:%-2v'
                local search = statusline.section_searchcount { trunc_width = 75 }
                return statusline.combine_groups {
                    { hl = mode_hl, strings = { mode } },
                    { hl = 'MiniStatuslineDevinfo', strings = { git, diff, lsp } },
                    '%<', -- Shorten the filename before dropping project counts.
                    { hl = 'MiniStatuslineFilename', strings = { filename } },
                    '%=',
                    { hl = 'MiniStatuslineFileinfo', strings = { diagnostics.section(), fileinfo } },
                    { hl = mode_hl, strings = { search, location } },
                }
            end,
        },
    }

    -- Install project counters and highlights after Mini creates its groups.
    diagnostics.setup()
end

return M
