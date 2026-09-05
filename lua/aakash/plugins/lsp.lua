-- ============================================================
-- LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================

-- [[ LSP Configuration ]]
-- Brief aside: **What is LSP?**
--
-- LSP is an initialism you've probably heard, but might not understand what it is.
--
-- LSP stands for Language Server Protocol. It's a protocol that helps editors
-- and language tooling communicate in a standardized fashion.
--
-- In general, you have a "server" which is some tool built to understand a particular
-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
-- processes that communicate with some "client" - in this case, Neovim!
--
-- LSP provides Neovim with features like:
--  - Go to definition
--  - Find references
--  - Autocompletion
--  - Symbol Search
--  - and more!
--
-- Thus, Language Servers are external tools that must be installed separately from
-- Neovim. This is where `mason` and related plugins come into play.
--
-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
-- and elegantly composed help section, `:help lsp-vs-treesitter`

-- General-purpose servers live here. Language modules extend this registry
-- through lazy.nvim's merged `opts` instead of creating a second LSP setup path.
-- See `:help lsp-config` for server configuration details.
---@type table<string, vim.lsp.Config>
local servers = {
  -- gopls = {},
  --
  -- Some languages (like typescript) have entire language plugins that can be useful:
  --    https://github.com/pmizio/typescript-tools.nvim
  --
  -- But for many setups, the LSP (`ts_ls`) will work just fine
  -- ts_ls = {},

  -- stylua = {}, -- Used to format Lua code

  -- Special Lua Config, as recommended by neovim help docs
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      end

      -- Preserve settings contributed by another spec before adding Lua runtime defaults.
      local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
      client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
        runtime = {
          version = 'LuaJIT',
          path = { 'lua/?.lua', 'lua/?/init.lua' },
        },
        workspace = {
          checkThirdParty = false,
          -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
          --  See https://github.com/neovim/nvim-lspconfig/issues/3189
          -- library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
          --   '${3rd}/luv/library',
          --   '${3rd}/busted/library',
          -- }),
        },
      })
    end,
    ---@type lspconfig.settings.lua_ls
    settings = {
      Lua = {
        format = { enable = false }, -- Disable formatting (formatting is done by stylua)
      },
    },
  },
}

-- Automatically install LSPs and related tools to stdpath for Neovim
local ensure_installed = vim.tbl_keys(servers)
vim.list_extend(ensure_installed, {
  -- You can add other tools here that you want Mason to install
  'stylua',
})

return {
  {
    'smjonas/inc-rename.nvim',
    lazy = false,
    opts = { input_buffer_type = 'snacks' },
  },

  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on Lua files, as recommended by LazyDev
    opts = {
      library = {
        -- Load vim.uv types only when vim.uv is used.
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  {
    'mason-org/mason-lspconfig.nvim',
    dependencies = {
      {
        'mason-org/mason.nvim',
        opts = {},
      },
      {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        opts = { ensure_installed = ensure_installed },
        opts_extend = { 'ensure_installed' },
      },
      { 'neovim/nvim-lspconfig' },
      {
        -- Useful status updates for LSP.
        'j-hui/fidget.nvim',
        opts = {},
      },
    },
    opts = {
      -- Translates between nvim-lspconfig server names and Mason package names
      -- (for example, lua_ls <-> lua-language-server).
      automatic_enable = false,
      servers = servers,
    },
    config = function(_, opts)
      local configured_servers = opts.servers or {}
      local mason_opts = vim.deepcopy(opts)
      mason_opts.servers = nil
      require('mason-lspconfig').setup(mason_opts)

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('aakash-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          if client and client:supports_method('textDocument/rename', event.buf) then
            vim.keymap.set('n', 'grn', function() return ':IncRename ' .. vim.fn.expand '<cword>' end, {
              buffer = event.buf,
              desc = 'LSP: [R]e[n]ame',
              expr = true,
            })
          end

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function()
              local filter = { bufnr = event.buf }
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      for name, server in pairs(configured_servers) do
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { '<leader>c', group = '[C]ode' },
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      })
    end,
  },
}
