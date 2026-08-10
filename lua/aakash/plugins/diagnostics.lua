return {
  -- Inline diagnostics
  {
    'rachartier/tiny-inline-diagnostic.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>td',
        '<cmd>TinyInlineDiag toggle<CR>',
        desc = '[T]oggle inline [D]iagnostics',
      },
    },
    opts = {
      preset = 'modern',
      options = {
        use_icons_from_diagnostic = true,

        show_code = true,
        show_source = false,
        show_related = {
          enabled = true,
          max_count = 3,
        },

        show_all_diags_on_cursorline = true,
        severity = {
          vim.diagnostic.severity.ERROR,
          vim.diagnostic.severity.WARN,
          vim.diagnostic.severity.INFO,
          vim.diagnostic.severity.HINT,
        },

        softwrap = 30,
        overflow = {
          mode = 'wrap',
        },
        break_line = {
          enabled = false,
        },

        multilines = {
          enabled = true,
          always_show = true,
          severity = {
            vim.diagnostic.severity.ERROR,
          },
        },

        enable_on_insert = false,
        enable_on_select = false,
        override_open_float = true,
      },
    },
  },

  -- Trouble
  {
    'folke/trouble.nvim',
    cmd = { 'Trouble' },
    opts = {},
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<CR>',
        desc = 'Diagnostics: project',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<CR>',
        desc = 'Diagnostics: current buffer',
      },
    },
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>x', group = 'Diagnostics' })
    end,
  },
}
