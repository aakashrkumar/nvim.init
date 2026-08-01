return {
  -- [[ Markdown ]]
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-mini/mini.nvim',
    },
    config = function()
      -- Render headings, lists, checkboxes, tables, links, and code blocks.
      -- Markdown source remains visible while you are in Insert mode.
      require('render-markdown').setup {
        render_modes = { 'n', 'c' },

        -- Provides checkbox and callout completion through blink.cmp.
        completions = {
          lsp = { enabled = true },
        },
      }

      vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<CR>', {
        desc = '[T]oggle [M]arkdown rendering',
      })
    end,
  },

  -- Vim-style operations for Markdown formatting, links, lists, and headings.
  {
    'tadmccorkle/markdown.nvim',
    ft = 'markdown',
    init = function()
      -- `init` runs during startup even though the plugin itself waits for a
      -- Markdown buffer. Registering this autocmd here ensures the first such
      -- buffer receives the same local writing options as every later one.
      -- Prose-friendly settings applied only to Markdown buffers.
      vim.api.nvim_create_autocmd('FileType', {
        desc = 'Markdown writing settings',
        group = vim.api.nvim_create_augroup('markdown-writing', { clear = true }),
        pattern = 'markdown',
        callback = function()
          -- Visually wrap long paragraphs without altering the file.
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true

          -- Enable Neovim's built-in spell checker.
          vim.opt_local.spell = true
          vim.opt_local.spelllang = 'en_us'

          -- Do not automatically insert hard line breaks.
          vim.opt_local.textwidth = 0
          vim.opt_local.formatoptions:remove { 't' }
        end,
      })
    end,
    opts = {
      on_attach = function(bufnr)
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = bufnr,
            silent = true,
            desc = desc,
          })
        end

        map('n', '<leader>mx', '<cmd>MDTaskToggle<CR>', 'Markdown: toggle task')
        map('x', '<leader>mx', ':MDTaskToggle<CR>', 'Markdown: toggle selected tasks')
        map('n', '<leader>mo', '<cmd>MDListItemBelow<CR>', 'Markdown: list item below')
        map('n', '<leader>mO', '<cmd>MDListItemAbove<CR>', 'Markdown: list item above')
        map('n', '<leader>mc', '<cmd>MDToc<CR>', 'Markdown: show table of contents')
      end,
    },
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>m', group = '[M]arkdown' })
    end,
  },
}
