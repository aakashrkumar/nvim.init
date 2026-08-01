return {
  -- [[ Installing and Configuring Plugins ]]
  --
  -- lazy.nvim plugin specifications are Lua tables. The first value identifies
  -- the GitHub repository; other keys describe configuration and loading.
  --
  -- For most plugins it is not enough to install them: their `setup()` function
  -- must also run. lazy.nvim's `opts` field calls that setup function with the
  -- table you provide. Use `config` when setup requires additional Lua logic.
  --
  -- For example, lets say we want to install `guess-indent.nvim` - a plugin for
  -- automatically detecting and setting the indentation.
  --
  -- We first install it from https://github.com/NMAC427/guess-indent.nvim
  -- and then call its `setup()` function to start it with default settings.
  {
    'NMAC427/guess-indent.nvim',
    opts = {},
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  -- treesitter text objets
  {
    'nvim-mini/mini.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
    },
    config = function()
      -- [[ mini.nvim ]]
      --  A collection of various small independent plugins/modules

      -- If a nerd font is available, load the icons module for pretty icons in various plugins.
      if vim.g.have_nerd_font then
        require('mini.icons').setup()
        -- Used for backwards compatibility with plugins that require `nvim-web-devicons` (e.g. telescope.nvim)
        MiniIcons.mock_nvim_web_devicons()
      end

      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote

      local ai = require 'mini.ai'
      require('mini.ai').setup {
        -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
        mappings = {
          around_next = 'aa',
          inside_next = 'ii',
        },
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter {
            a = {
              '@block.outer',
              '@conditional.outer',
              '@loop.outer',
            },
            i = {
              '@block.inner',
              '@conditional.inner',
              '@loop.inner',
            },
          },

          -- Around/inside a function definition.
          f = ai.gen_spec.treesitter {
            a = '@function.outer',
            i = '@function.inner',
          },

          -- Around/inside a class, struct, impl, or equivalent language construct.
          c = ai.gen_spec.treesitter {
            a = '@class.outer',
            i = '@class.inner',
          },

          -- Mini.ai normally uses `f` for a function call. Since `f` now means
          -- function definition, preserve function-call text objects under `u`,
          -- matching LazyVim's convention: "usage".
          u = ai.gen_spec.function_call(),

          -- Function call without including a dotted receiver.
          U = ai.gen_spec.function_call {
            name_pattern = '[%w_]',
          },
        },
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- Set `use_icons` to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end

      require('mini.files').setup {
        windows = { preview = true, width_preview = 40 },
        options = { permanent_delete = false },
      }

      vim.keymap.set('n', '-', function()
        local file = vim.api.nvim_buf_get_name(0)
        MiniFiles.open(file ~= '' and file or nil)
      end, { desc = 'File explorer (at current file)' })

      vim.keymap.set('n', '<leader>e', function() MiniFiles.open() end, { desc = 'File [E]xplorer (cwd)' })

      require('mini.pairs').setup()
      require('mini.splitjoin').setup()
      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  -- [[ Undo history visualizer ]]
  {
    'mbbill/undotree',
    cmd = 'UndotreeToggle',
    init = function()
      vim.g.undotree_WindowLayout = 3
      vim.g.undotree_SetFocusWhenToggle = 1
      vim.g.undotree_ShortIndicators = 1
    end,
    keys = {
      {
        '<leader>u',
        '<cmd>UndotreeToggle<CR>',
        silent = true,
        desc = 'Toggle [U]ndo tree',
      },
    },
  },

  {
    'ThePrimeagen/vim-be-good',
    cmd = 'VimBeGood',
  },
}
