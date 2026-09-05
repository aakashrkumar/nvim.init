return {
  -- ============================================================
  -- AUTOCOMPLETE & SNIPPETS
  -- blink.cmp and luasnip setup
  -- ============================================================
  {
    -- [[ Snippet Engine ]]

    -- NOTE: You can also specify plugin using a version range for its git tag.
    -- lazy.nvim accepts version ranges in a spec's `version` field; see
    -- https://lazy.folke.io/spec/versioning for the supported forms.
    'L3MON4D3/LuaSnip',
    version = 'v2.*',
    -- LuaSnip's optional JavaScript-regexp support uses this documented build
    -- command. Preserve the source guard on platforms without `make`.
    build = vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 and 'make install_jsregexp' or nil,
    dependencies = {
      {
        -- `friendly-snippets` contains a variety of premade snippets.
        --    See the README about individual language/framework/plugin snippets:
        --    https://github.com/rafamadriz/friendly-snippets
        --
        'rafamadriz/friendly-snippets',
      },
    },
    config = function()
      require('luasnip').setup {}
      require('luasnip.loaders.from_vscode').lazy_load()
    end,
  },

  -- [[ Autocomplete Engine ]]
  {
    'saghen/blink.cmp',
    version = '1.*',
    dependencies = {
      'L3MON4D3/LuaSnip',
      {
        'xzbdmw/colorful-menu.nvim',
        opts = {
          max_width = 48,
          ls = {
            ['rust-analyzer'] = {
              align_type_to_right = false,
            },
          },
        },
      },
    },
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See `:help blink-cmp-config-keymap` for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        keyword = { range = 'full' },
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
        menu = {
          border = 'rounded',
          draw = {
            columns = { { 'kind_icon' }, { 'label', gap = 1 }, { 'kind' } },
            components = {
              label = {
                text = function(ctx) return require('colorful-menu').blink_components_text(ctx) end,
                highlight = function(ctx) return require('colorful-menu').blink_components_highlight(ctx) end,
              },
            },
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 400,
          window = { border = 'rounded' },
        },
      },

      sources = {
        default = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer' },
        providers = {
          lazydev = {
            name = 'LazyDev',
            module = 'lazydev.integrations.blink',
            score_offset = 100,
          },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Shows a signature help window while you type arguments for a function
      signature = {
        enabled = true,
        window = { border = 'rounded' },
      },
    },
  },
}
