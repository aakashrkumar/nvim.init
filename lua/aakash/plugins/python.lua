-- ============================================================
-- PYTHON
-- Language servers, environments, formatting, and debugging
-- ============================================================

---@type table<string, vim.lsp.Config>
local servers = {
  basedpyright = {
    settings = {
      basedpyright = {
        -- Ruff is the single owner of import organization.
        disableOrganizeImports = true,
      },
    },
  },
  ruff = {
    on_attach = function(client)
      -- BasedPyright provides richer Python hover information.
      client.server_capabilities.hoverProvider = false
    end,
  },
}

return {
  {
    'mason-org/mason-lspconfig.nvim',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      for name, server in pairs(servers) do
        opts.servers[name] = server
      end
    end,
  },

  {
    'linux-cultist/venv-selector.nvim',
    cmd = 'VenvSelect',
    ft = 'python',
    dependencies = { 'folke/snacks.nvim' },
    keys = {
      {
        '<leader>cv',
        '<cmd>VenvSelect<CR>',
        ft = 'python',
        desc = 'Python: select virtual environment',
      },
    },
    opts = {
      options = {
        picker = 'snacks',
      },
    },
  },

  {
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = { 'mfussenegger/nvim-dap' },
    keys = {
      {
        '<leader>dPt',
        function() require('dap-python').test_method() end,
        ft = 'python',
        desc = 'Python: debug nearest test',
      },
      {
        '<leader>dPc',
        function() require('dap-python').test_class() end,
        ft = 'python',
        desc = 'Python: debug test class',
      },
      {
        '<leader>dPs',
        function() require('dap-python').debug_selection() end,
        mode = 'x',
        ft = 'python',
        desc = 'Python: debug selection',
      },
    },
    config = function() require('dap-python').setup 'debugpy-adapter' end,
  },

  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.python = { 'ruff_organize_imports', 'ruff_format' }

      local general_format_on_save = opts.format_on_save
      opts.format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == 'python' then return { timeout_ms = 1000 } end
        if general_format_on_save then return general_format_on_save(bufnr) end
      end
    end,
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, tool in ipairs { 'basedpyright', 'debugpy', 'ruff' } do
        if not vim.tbl_contains(opts.ensure_installed, tool) then
          table.insert(opts.ensure_installed, tool)
        end
      end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>dP', group = 'Debug [P]ython', mode = { 'n', 'x' } })
    end,
  },
}
