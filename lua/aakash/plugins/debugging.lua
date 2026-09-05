return {
  -- ============================================================
  -- DEBUGGING
  -- Shared DAP UI, lifecycle, and keymaps
  -- ============================================================

  -- nvim-dap has no `setup()`. Language modules add adapters and
  -- configurations through these merged `opts` (mirroring the `servers`
  -- registry in `lsp.lua`) and `config` copies them onto nvim-dap, so no
  -- module needs its own `config` on this plugin.
  {
    'mfussenegger/nvim-dap',
    opts = {
      ---@type table<string, dap.Adapter|fun(callback: fun(adapter: dap.Adapter), config: dap.Configuration)>
      adapters = {},
      -- Keyed by filetype. See `:help dap-configuration`.
      ---@type table<string, dap.Configuration[]>
      configurations = {},
      -- Compute configurations per buffer, e.g. only inside a certain kind
      -- of project. See `:help dap-providers-configs`.
      ---@type table<string, fun(bufnr: integer): dap.Configuration[]>
      providers = {},
    },
    config = function(_, opts)
      local dap = require 'dap'
      for name, adapter in pairs(opts.adapters) do
        dap.adapters[name] = adapter
      end
      for filetype, configurations in pairs(opts.configurations) do
        dap.configurations[filetype] = configurations
      end
      for name, provider in pairs(opts.providers) do
        dap.providers.configs[name] = provider
      end
    end,
  },

  {
    'rcarriga/nvim-dap-ui',
    dependencies = {
      { 'mfussenegger/nvim-dap' },
      { 'nvim-neotest/nvim-nio' },
      {
        'theHamsta/nvim-dap-virtual-text',
        main = 'nvim-dap-virtual-text',
        opts = {},
      },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      dapui.setup {}

      local debug_step_keymaps = {
        { '<Down>', dap.step_over, '[D]ebug: step [O]ver' },
        { '<Right>', dap.step_into, '[D]ebug: step [I]nto' },
        { '<Left>', dap.step_out, '[D]ebug: step [O]ut' },
        { '<Up>', dap.restart_frame, '[D]ebug: [R]estart frame' },
      }

      -- Follow DAP's session lifecycle, including disconnects and adapter failures.
      -- Keep the mappings while another session is still alive, and restore the
      -- original global mappings after the last one closes. Buffer maps stay local.
      -- DAP UI still has one shared console for integrated-terminal sessions.
      local saved_step_keymaps
      dap.listeners.on_session.aakash_dap_ui = function(_, session)
        if session then
          if saved_step_keymaps then return end
          saved_step_keymaps = {}
          for _, mapping in ipairs(vim.api.nvim_get_keymap 'n') do
            for _, keymap in ipairs(debug_step_keymaps) do
              if mapping.lhs == keymap[1] then saved_step_keymaps[keymap[1]] = mapping end
            end
          end
          for _, keymap in ipairs(debug_step_keymaps) do
            vim.keymap.set('n', keymap[1], keymap[2], { silent = true, desc = keymap[3] })
          end
          dapui.open()
        elseif saved_step_keymaps then
          for _, keymap in ipairs(debug_step_keymaps) do
            pcall(vim.keymap.del, 'n', keymap[1])
            local previous = saved_step_keymaps[keymap[1]]
            if previous then vim.fn.mapset('n', false, previous) end
          end
          saved_step_keymaps = nil
          dapui.close()
        end
      end

      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, {
        desc = '[D]ebug: toggle [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dB', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, {
        desc = '[D]ebug: conditional [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dh', function() dap.set_breakpoint(nil, vim.fn.input 'Hit condition: ') end, {
        desc = '[D]ebug: breakpoint [H]it condition',
      })

      vim.keymap.set('n', '<leader>dl', function() dap.set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end, {
        desc = '[D]ebug: [L]og point',
      })

      vim.keymap.set('n', '<leader>dr', dap.repl.open, {
        desc = '[D]ebug: open [R]EPL',
      })

      vim.keymap.set('n', '<leader>dc', dap.continue, {
        desc = '[D]ebug: [C]ontinue',
      })

      vim.keymap.set('n', '<leader>di', dap.step_into, {
        desc = '[D]ebug: step [I]nto',
      })

      vim.keymap.set('n', '<leader>do', dap.step_over, {
        desc = '[D]ebug: step [O]ver',
      })

      vim.keymap.set('n', '<leader>dO', dap.step_out, {
        desc = '[D]ebug: step [O]ut',
      })

      vim.keymap.set('n', '<leader>dt', dap.terminate, {
        desc = '[D]ebug: [T]erminate',
      })

      vim.keymap.set('n', '<leader>du', dapui.toggle, {
        desc = '[D]ebug: toggle [U]I',
      })
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>d', group = '[D]ebug' })
    end,
  },
}
