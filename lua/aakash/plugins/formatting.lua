return {
  -- ============================================================
  -- FORMATTING
  -- conform.nvim setup and keymap
  -- ============================================================
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
      format_on_save = function(bufnr)
        -- You can specify filetypes to autoformat on save here:
        local enabled_filetypes = {
          lua = true,
          python = true,
          java = true,
        }
        if enabled_filetypes[vim.bo[bufnr].filetype] then
          return { timeout_ms = 1000 }
        else
          return nil
        end
      end,
      default_format_opts = {
        lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
      },
      -- You can also specify external formatters in here.
      formatters_by_ft = {
        -- Conform can also run multiple formatters sequentially
        python = { 'ruff_organize_imports', 'ruff_format' },
        lua = { 'stylua' },
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
}
