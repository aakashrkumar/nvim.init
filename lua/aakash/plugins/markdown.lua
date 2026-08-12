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

  -- Vault-aware navigation and note creation for the active Obsidian vault.
  -- Generic Markdown editing and rendering remain owned by the plugins above.
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    lazy = false,
    keys = {
      { '<leader>oq', '<cmd>Obsidian quick_switch<CR>', desc = '[O]bsidian: [Q]uick switch' },
      { '<leader>os', '<cmd>Obsidian search<CR>', desc = '[O]bsidian: [S]earch vault' },
      { '<leader>ot', '<cmd>Obsidian today<CR>', desc = '[O]bsidian: [T]oday' },
      { '<leader>on', '<cmd>Obsidian new<CR>', desc = '[O]bsidian: [N]ew note' },
      { '<leader>ob', '<cmd>Obsidian backlinks<CR>', desc = '[O]bsidian: [B]acklinks' },
      { '<leader>oo', '<cmd>Obsidian open<CR>', desc = '[O]bsidian: [O]pen in app' },
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = 'main',
          path = '~/Documents/Notes/Main',
        },
      },
      notes_subdir = '010.Inbox',
      new_notes_location = 'notes_subdir',
      note_id_func = function(title)
        local trimmed_title = title and vim.trim(title)
        if trimmed_title and trimmed_title ~= '' then return trimmed_title end
        return require('obsidian.builtin').zettel_id()
      end,
      picker = {
        name = 'snacks.picker',
      },
      templates = {
        folder = 'Settings/Templates',
      },
      daily_notes = {
        folder = '100.Daily',
        template = 'New Daily Note.md',
        default_tags = {},
        workdays_only = false,
      },
      attachments = {
        folder = '700.Resources/709.Attachments',
      },
      frontmatter = {
        enabled = false,
      },
      ui = {
        enable = false,
      },
      footer = {
        enabled = false,
      },
      statusline = {
        enabled = false,
      },
    },
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>m', group = '[M]arkdown' })
      table.insert(opts.spec, { '<leader>o', group = '[O]bsidian' })
    end,
  },
}
