-- [[ Typst indentation ]]
-- This runs after $VIMRUNTIME/indent/typst.vim; see `:help after-directory`.
-- Use the shared defaults instead of the runtime's two-space indentation.
vim.bo.shiftwidth = vim.go.shiftwidth
vim.bo.softtabstop = vim.go.softtabstop
