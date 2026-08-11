return {
  -- ============================================================
  -- SEARCH & NAVIGATION
  -- Telescope setup, keymaps, LSP picker mappings
  -- ============================================================
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { 'nvim-telescope/telescope-ui-select.nvim' },
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        -- Telescope FZF Native's installation guide requires this build step.
        build = 'make',
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
    },
    config = function()
      -- [[ Fuzzy Finder (files, lsp, etc) ]]
      --
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- There are lots of other alternative pickers (like snacks.picker, or fzf-lua)
      -- so feel free to experiment and see what you like!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!
      --
      -- NOTE: A lazy.nvim spec can declare multiple dependencies at once. They
      -- are available before this plugin's `config` function runs.

      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'

      -- Snacks normally matches each document symbol by its own name. Add its
      -- ancestors to the hidden match text so searching for a type such as
      -- `Hex` also keeps that type's fields and methods in the result tree.
      local function add_symbol_ancestors(item)
        local parent = item.parent
        while parent and not parent.root do
          if parent.name and parent.name ~= '' then
            item.text = item.text .. ' ' .. parent.name
          end
          parent = parent.parent
        end
        return item
      end

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Add LSP pickers when an LSP attaches to a buffer. Snacks owns symbol
      -- and implementation navigation; Telescope remains useful for the other
      -- LSP results and the general-purpose searches above.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('navigation-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf

          -- Find references for the word under your cursor.
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

          -- Find callers of the function under your cursor.
          vim.keymap.set('n', 'grI', builtin.lsp_incoming_calls, { buffer = buf, desc = '[G]oto [I]ncoming calls' })

          -- Find functions called by the function under your cursor.
          vim.keymap.set('n', 'grO', builtin.lsp_outgoing_calls, { buffer = buf, desc = '[G]oto [O]utgoing calls' })

          -- Jump to the implementation of the word under your cursor.
          -- Useful when your language has ways of declaring types without an actual implementation.
          vim.keymap.set('n', 'gri', function() Snacks.picker.lsp_implementations() end, {
            buffer = buf,
            desc = '[G]oto [I]mplementation (Snacks)',
          })

          -- Jump to the definition of the word under your cursor.
          -- This is where a variable was first declared, or where a function is defined, etc.
          -- To jump back, press <C-t>.
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

          -- Fuzzy find all the symbols in your current document.
          -- Symbols are things like variables, functions, types, etc.
          vim.keymap.set('n', 'gO', function()
            Snacks.picker.lsp_symbols {
              tree = true,
              keep_parents = true,
              -- rust-analyzer represents `impl` blocks as Object symbols.
              -- Keep them so their methods retain the source hierarchy.
              filter = { rust = true },
              transform = add_symbol_ancestors,
            }
          end, { buffer = buf, desc = 'Open Document Symbols (Snacks)' })

          -- Fuzzy find all the symbols in your current workspace.
          -- Similar to document symbols, except searches over your entire project.
          vim.keymap.set('n', 'gW', function() Snacks.picker.lsp_workspace_symbols() end, {
            buffer = buf,
            desc = 'Open Workspace Symbols (Snacks)',
          })

          -- Jump to the type of the word under your cursor.
          -- Useful when you're not sure what type a variable is and you want to see
          -- the definition of its *type*, not where it was *defined*.
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set(
        'n',
        '<leader>sn',
        function() builtin.find_files { cwd = vim.fn.stdpath 'config', follow = true } end,
        { desc = '[S]earch [N]eovim files' }
      )
    end,
  },

  -- [[ Yank history ]]
  {
    'gbprod/yanky.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('yanky').setup {
        -- ShaDa persists history across Neovim sessions without another dependency.
        ring = {
          storage = 'shada',
        },

        -- Include text copied outside Neovim when running locally.
        -- Avoid clipboard synchronization over SSH.
        system_clipboard = {
          sync_with_ring = not vim.env.SSH_CONNECTION,
        },

        -- Match LazyVim's short highlight duration.
        highlight = {
          timer = 150,
        },
      }

      -- Register Yanky's Telescope picker.
      pcall(require('telescope').load_extension, 'yank_history')

      -- Preserve normal yank/paste behavior while recording it in Yanky's history.
      vim.keymap.set({ 'n', 'x' }, 'y', '<Plug>(YankyYank)', {
        desc = 'Yank text',
      })

      vim.keymap.set({ 'n', 'x' }, 'p', '<Plug>(YankyPutAfter)', {
        desc = 'Put text after cursor',
      })

      vim.keymap.set({ 'n', 'x' }, 'P', '<Plug>(YankyPutBefore)', {
        desc = 'Put text before cursor',
      })

      vim.keymap.set({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)', {
        desc = 'Put text after cursor and move after it',
      })

      vim.keymap.set({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)', {
        desc = 'Put text before cursor and move after it',
      })

      -- After pasting, cycle through older/newer yank-history entries.
      vim.keymap.set('n', '[y', '<Plug>(YankyCycleForward)', {
        desc = 'Previous yank-history entry',
      })

      vim.keymap.set('n', ']y', '<Plug>(YankyCycleBackward)', {
        desc = 'Next yank-history entry',
      })

      -- Browse and select from the complete history.
      vim.keymap.set({ 'n', 'x' }, '<leader>sy', function() require('telescope').extensions.yank_history.yank_history() end, {
        desc = '[S]earch [Y]ank history',
      })
    end,
  },

  -- [[ Harpoon 2 ]]
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local harpoon = require 'harpoon'

      -- Required by Harpoon 2 to create its autocmds.
      harpoon:setup()

      -- Highlight and focus the current file when opening the Harpoon menu.
      harpoon:extend(require('harpoon.extensions').builtins.highlight_current_file())

      -- Add the current file to this project's Harpoon list.
      vim.keymap.set('n', '<leader>a', function() harpoon:list():add() end, {
        desc = 'Harpoon: [A]dd current file',
      })

      -- Open Harpoon's editable list.
      vim.keymap.set('n', '<leader>p', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, {
        desc = 'Harpoon: open [P]inned files',
      })

      -- Jump directly to Harpoon slots 1–4.
      for index = 1, 4 do
        local slot = index

        vim.keymap.set('n', '<leader>' .. slot, function() harpoon:list():select(slot) end, {
          desc = ('Harpoon: select file %d'):format(slot),
        })
      end

      -- Cycle through the Harpoon list, wrapping at either end.
      vim.keymap.set('n', '<leader>[', function() harpoon:list():prev { ui_nav_wrap = true } end, {
        desc = 'Harpoon: previous file',
      })

      vim.keymap.set('n', '<leader>]', function() harpoon:list():next { ui_nav_wrap = true } end, {
        desc = 'Harpoon: next file',
      })
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } })
    end,
  },

  -- [[ Search and replace ]]
  {
    'MagicDuck/grug-far.nvim',
    cmd = { 'GrugFar', 'GrugFarWithin' },
    opts = {},
    keys = {
      {
        '<leader>sR',
        function() require('grug-far').open() end,
        desc = '[S]earch and [R]eplace',
      },
      {
        '<leader>sR',
        function() require('grug-far').with_visual_selection() end,
        mode = 'v',
        desc = '[S]earch and [R]eplace',
      },
    },
  },

  -- [[ Quickfix ]]
  {
    'stevearc/quicker.nvim',
    ft = 'qf',
    opts = {
      keys = {
        {
          '>',
          function() require('quicker').expand { before = 2, after = 2, add_to_existing = true } end,
          desc = 'Expand quickfix context',
        },
        {
          '<',
          function() require('quicker').collapse() end,
          desc = 'Collapse quickfix context',
        },
      },
    },
    keys = {
      {
        '<leader>q',
        function() require('quicker').toggle() end,
        desc = '[Q]uickfix',
      },
    },
  },

  -- [[ Enhanced jump motions ]]
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        '<leader>j',
        function() require('flash').jump() end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash jump',
      },
      {
        '<leader>J',
        function() require('flash').treesitter() end,
        mode = { 'n', 'x', 'o' },
        desc = 'Flash Treesitter',
      },
      {
        'r',
        function() require('flash').remote() end,
        mode = 'o',
        desc = 'Remote Flash',
      },
      {
        'R',
        function() require('flash').treesitter_search() end,
        mode = { 'o', 'x' },
        desc = 'Flash Treesitter search',
      },
      {
        '<C-s>',
        function() require('flash').toggle() end,
        mode = 'c',
        desc = 'Toggle Flash search',
      },
    },
  },
}
