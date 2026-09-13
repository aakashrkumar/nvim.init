-- [[ Format expressions ]]
-- Share Conform between gq and the format mapping without losing Vim's prose
-- wrapping. See `:help 'formatexpr'`: returning 1 asks Vim to handle the text.

local M = {}

---@return integer
function M.formatexpr()
    -- Keep native wrapping while typing, rather than invoking a code formatter.
    if vim.fn.mode():match '^[iR]' then return 1 end

    local conform = require 'conform'
    local formatters, lsp = conform.list_formatters_to_run(0)
    -- Conform returns 0 even when no formatter runs; let Vim wrap that text.
    if #formatters == 0 and not lsp then return 1 end
    return conform.formatexpr()
end

return M
