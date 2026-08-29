return {
  -- Rustation Vim
  -- [[ Rust ]]
  {
    'mrcjkb/rustaceanvim',
    -- To avoid being surprised by breaking changes, Rustaceanvim recommends a
    -- tagged major-version range. The plugin implements proper Neovim-native
    -- lazy loading itself, so its official lazy.nvim example sets `lazy = false`.
    version = '^9',
    lazy = false,
    -- This must be defined before rustaceanvim initializes.
    init = function()
      vim.g.rustaceanvim = {
        tools = {
          code_actions = {
            ui_select_fallback = true,
          },
          float_win_config = {
            border = 'rounded',
            auto_focus = true,
          },
        },

        server = {
          capabilities = require('blink.cmp').get_lsp_capabilities(),

          on_attach = function(client, bufnr)
            local map = function(lhs, rhs, desc)
              vim.keymap.set('n', lhs, rhs, {
                buffer = bufnr,
                silent = true,
                desc = 'Rust: ' .. desc,
              })
            end

            if client:supports_method('textDocument/inlayHint', bufnr) then
              vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end

            if client:supports_method('textDocument/codeLens', bufnr) then
              map('<leader>tl', function()
                local is_enabled = vim.lsp.codelens.is_enabled { bufnr = bufnr }
                vim.lsp.codelens.enable(not is_enabled, { bufnr = bufnr })
              end, 'Toggle CodeLens')
            end

            -- More powerful than ordinary LSP hover: the window is actionable.
            map('K', function() vim.cmd.RustLsp { 'hover', 'actions' } end, 'Hover actions')

            -- Shows Rustaceanvim's grouped code-action UI.
            map('grA', function() vim.cmd.RustLsp 'codeAction' end, 'Grouped code actions')

            map('<leader>rr', function() vim.cmd.RustLsp 'runnables' end, 'Runnables')

            map('<leader>rD', function() vim.cmd.RustLsp 'debuggables' end, 'Debuggables')

            map('<leader>re', function() vim.cmd.RustLsp { 'explainError', 'current' } end, 'Explain error')

            map('<leader>rE', function() vim.cmd.RustLsp { 'renderDiagnostic', 'current' } end, 'Render diagnostic')

            map('<leader>rm', function() vim.cmd.RustLsp 'expandMacro' end, 'Expand macro')

            map('<leader>rc', function() vim.cmd.RustLsp 'openCargo' end, 'Open Cargo.toml')

            map('<leader>rd', function() vim.cmd.RustLsp 'openDocs' end, 'Open documentation')
          end,

          default_settings = {
            ['rust-analyzer'] = {
              check = {
                command = 'clippy',
                extraArgs = { '--no-deps' },
              },

              completion = {
                -- Complete a call with its argument placeholders.
                fullFunctionSignatures = {
                  enable = true,
                },

                -- Can synthesize small expressions matching the expected type.
                -- Powerful, but occasionally adds completion noise.
                termSearch = {
                  enable = true,
                },
              },

              files = {
                exclude = {
                  '.direnv',
                  '.git',
                  '.jj',
                  '.venv',
                  'node_modules',
                  'target',
                  'venv',
                },
              },

              -- Enable only in projects where you normally build all features:
              -- cargo = {
              --   features = 'all',
              -- },
            },
          },
        },
      }
    end,
  },

  -- The general LSP list intentionally does not enable this server:
  -- rust_analyzer = {},
  -- Rustaceanvim's documentation warns that configuring rust-analyzer through
  -- both mechanisms can create conflicting clients.

  -- Creates
  {
    'Saecki/crates.nvim',
    -- This is the plugin's documented lazy-loading pattern: the first read of a
    -- Cargo manifest loads Crates and configures its completion/LSP helpers.
    event = 'BufRead Cargo.toml',
    opts = {
      completion = {
        crates = {
          enabled = true,
        },
      },

      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- Repeated lazy.nvim specs are merged with the primary specs in their owning
  -- feature modules. These functions extend shared options without replacing
  -- general formatting or installation settings.
  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.rust = { 'rustfmt' }

      local general_format_on_save = opts.format_on_save
      opts.format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == 'rust' then return { timeout_ms = 1000 } end
        if general_format_on_save then return general_format_on_save(bufnr) end
      end
    end,
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'codelldb') then table.insert(opts.ensure_installed, 'codelldb') end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>r', group = '[R]ust' })
    end,
  },
}
