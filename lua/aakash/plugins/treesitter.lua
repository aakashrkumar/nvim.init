return {
  -- ============================================================
  -- TREESITTER
  -- Parser installation, syntax highlighting, folds, indentation
  -- ============================================================
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      -- [[ Configure Treesitter ]]
      --  Used to highlight, edit, and navigate code
      --
      --  See `:help nvim-treesitter-intro`

      -- NOTE: You can also specify a branch or a specific commit

      -- Ensure basic parsers are installed
      local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
      require('nvim-treesitter').install(parsers)

      ---@param buf integer
      ---@param language string
      local function treesitter_try_attach(buf, language)
        -- Check if a parser exists and load it
        if not vim.treesitter.language.add(language) then return end
        -- Enable syntax highlighting and other treesitter features
        vim.treesitter.start(buf, language)

        -- Enable treesitter based folds
        -- For more info on folds see `:help folds`
        vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.wo.foldmethod = 'expr'

        -- Check if treesitter indentation is available for this language, and if so enable it
        -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
        local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

        -- Enable treesitter based indentation
        if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
      end

      local available_parsers = require('nvim-treesitter').get_available()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match

          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

          if vim.tbl_contains(installed_parsers, language) then
            -- Enable the parser if it is already installed
            treesitter_try_attach(buf, language)
          elseif vim.tbl_contains(available_parsers, language) then
            -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
            require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
          else
            -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
            treesitter_try_attach(buf, language)
          end
        end,
      })
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup {
        move = { set_jumps = true },
      }

      local modes = { 'n', 'x', 'o' }
      local mappings = {
        [']m'] = { method = 'goto_next_start', capture = '@function.outer', desc = 'Next function start' },
        [']M'] = { method = 'goto_next_end', capture = '@function.outer', desc = 'Next function end' },
        ['[m'] = { method = 'goto_previous_start', capture = '@function.outer', desc = 'Previous function start' },
        ['[M'] = { method = 'goto_previous_end', capture = '@function.outer', desc = 'Previous function end' },
        [']a'] = { method = 'goto_next_start', capture = '@parameter.inner', desc = 'Next argument start' },
        [']A'] = { method = 'goto_next_end', capture = '@parameter.inner', desc = 'Next argument end' },
        ['[a'] = { method = 'goto_previous_start', capture = '@parameter.inner', desc = 'Previous argument start' },
        ['[A'] = { method = 'goto_previous_end', capture = '@parameter.inner', desc = 'Previous argument end' },
      }

      local function set_textobject_mappings(buf)
        for lhs, mapping in pairs(mappings) do
          vim.keymap.set(modes, lhs, function()
            require('nvim-treesitter-textobjects.move')[mapping.method](mapping.capture, 'textobjects')
          end, { buffer = buf, desc = mapping.desc })
        end
      end

      -- Global fallbacks also cover untyped buffers. Reassert buffer-local maps
      -- after FileType so language ftplugins cannot replace these motions.
      set_textobject_mappings(nil)
      local group = vim.api.nvim_create_augroup('TreesitterTextobjectsMappings', { clear = true })
      vim.api.nvim_create_autocmd('FileType', {
        group = group,
        callback = function(args)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then set_textobject_mappings(args.buf) end
          end)
        end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then set_textobject_mappings(buf) end
      end
    end,
  },

  {
    'nvim-treesitter/nvim-treesitter-context',
    lazy = false,
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      mode = 'cursor',
      max_lines = 3,
    },
    config = function(_, opts)
      require('treesitter-context').setup(opts)
      vim.keymap.set('n', '<leader>tc', '<cmd>TSContext toggle<CR>', {
        desc = '[T]oggle code [C]ontext',
      })
    end,
  },
}
