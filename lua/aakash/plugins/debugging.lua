return {
  -- ============================================================
  -- DEBUGGING
  -- Shared DAP UI, lifecycle, and keymaps
  -- ============================================================
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

      dap.listeners.after.event_initialized.aakash_dap_step_keymaps = function()
        for _, keymap in ipairs(debug_step_keymaps) do
          vim.keymap.set('n', keymap[1], keymap[2], {
            silent = true,
            desc = keymap[3],
          })
        end
      end

      local function clear_debug_step_keymaps()
        for _, keymap in ipairs(debug_step_keymaps) do
          pcall(vim.keymap.del, 'n', keymap[1])
        end
      end

      dap.listeners.before.event_terminated.aakash_dap_step_keymaps = clear_debug_step_keymaps
      dap.listeners.before.event_exited.aakash_dap_step_keymaps = clear_debug_step_keymaps

      dap.listeners.before.attach.aakash_dap_ui = function() dapui.open() end
      dap.listeners.before.launch.aakash_dap_ui = function() dapui.open() end
      dap.listeners.before.event_terminated.aakash_dap_ui = function() dapui.close() end
      dap.listeners.before.event_exited.aakash_dap_ui = function() dapui.close() end

      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, {
        desc = '[D]ebug: toggle [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dB', function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end, {
        desc = '[D]ebug: conditional [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dh', function()
        dap.set_breakpoint(nil, vim.fn.input 'Hit condition: ')
      end, {
        desc = '[D]ebug: breakpoint [H]it condition',
      })

      vim.keymap.set('n', '<leader>dl', function()
        dap.set_breakpoint(nil, nil, vim.fn.input 'Log point message: ')
      end, {
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
