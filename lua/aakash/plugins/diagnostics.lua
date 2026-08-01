return {
  {
    'rachartier/tiny-inline-diagnostic.nvim',
    event = 'VeryLazy',
    opts = {
      preset = 'modern',

      signs = {
        diag = '',
      },

      options = {
        use_icons_from_diagnostic = false,
        override_open_float = true,
        multilines = { enabled = true },
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
