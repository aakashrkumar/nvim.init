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
    'igorlfs/nvim-dap-view',
    version = '1.*',
    lazy = false,
    dependencies = { 'mfussenegger/nvim-dap' },
    config = function()
      local dap = require 'dap'
      local dapview = require 'dap-view'

      dapview.setup {
        winbar = {
          sections = { 'scopes', 'watches', 'threads', 'breakpoints', 'exceptions', 'repl' },
          default_section = 'scopes',
          show_keymap_hints = false,
          -- Keep readable key hints and controls visible beside the console.
          base_sections = {
            scopes = { label = 'Vars:S', keymap = 'S' },
            watches = { label = 'Watch:W', keymap = 'W' },
            threads = { label = 'Stack:T', keymap = 'T' },
            breakpoints = { label = 'BP:B', keymap = 'B' },
            exceptions = { label = 'EX:E', keymap = 'E' },
            repl = { label = 'REPL:R', keymap = 'R' },
          },
          controls = {
            enabled = true,
            buttons = { 'play', 'step_over', 'step_into', 'step_out', 'terminate', 'disconnect' },
          },
        },
        windows = {
          size = 0.33,
          position = 'below',
          terminal = { size = 0.35, position = 'right' },
        },
        hover = { border = 'rounded' },
        help = { border = 'rounded' },
        virtual_text = { enabled = true, position = 'eol' },
        auto_toggle = 'keep_terminal',
        follow_tab = true,
      }

      -- Reuse visible source buffers, otherwise open a safe tab rather than
      -- replacing a debugger pane. The dock follows native DAP source jumps.
      dap.defaults.fallback.switchbuf = 'usevisible,usetab,newtab'

      -- Internal buffer URIs are not useful status labels for the debug dock.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'dap-view', 'dap-view-term', 'dap-repl' },
        group = vim.api.nvim_create_augroup('aakash-dap-statusline', { clear = true }),
        callback = function(event)
          local titles = { ['dap-view'] = 'Debug inspector', ['dap-view-term'] = 'Program output', ['dap-repl'] = 'Debug REPL' }
          local text = '%#MiniStatuslineDevinfo# ' .. titles[vim.bo[event.buf].filetype] .. ' %='
          local function content() return text end
          vim.b[event.buf].ministatusline_config = { content = { active = content, inactive = content } }
        end,
      })

      local function set_debug_highlights()
        for name, link in pairs {
          DapBreakpoint = 'DiagnosticError',
          DapBreakpointCondition = 'DiagnosticWarn',
          DapLogPoint = 'DiagnosticInfo',
          DapBreakpointRejected = 'Comment',
          DapStopped = 'DiagnosticWarn',
          DapStoppedLine = 'DiagnosticVirtualTextWarn',
        } do
          vim.api.nvim_set_hl(0, name, { link = link })
        end
      end
      set_debug_highlights()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('aakash-dap-highlights', { clear = true }),
        callback = set_debug_highlights,
      })
      for name, text in pairs {
        DapBreakpoint = '●',
        DapBreakpointCondition = '◆',
        DapLogPoint = '◉',
        DapBreakpointRejected = '○',
        DapStopped = '▶',
      } do
        vim.fn.sign_define(name, {
          text = text,
          texthl = name,
          numhl = name,
          linehl = name == 'DapStopped' and 'DapStoppedLine' or '',
        })
      end

      local debug_step_keymaps = {
        { '<Down>', dap.step_over, '[D]ebug: step [O]ver' },
        { '<Right>', dap.step_into, '[D]ebug: step [I]nto' },
        { '<Left>', dap.step_out, '[D]ebug: step [O]ut' },
        { '<Up>', dap.restart_frame, '[D]ebug: [R]estart frame' },
      }

      -- Follow DAP's session lifecycle, including disconnects and adapter failures.
      -- Keep the mappings while another session is still alive, and restore the
      -- original global mappings after the last one closes. Buffer maps stay local.
      local saved_step_keymaps
      dap.listeners.on_session.aakash_dap_step_keys = vim.schedule_wrap(function()
        -- Read the current session after scheduling: a queued close must not
        -- restore the arrows if another session has already taken its place.
        if dap.session() then
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
        elseif saved_step_keymaps then
          for _, keymap in ipairs(debug_step_keymaps) do
            pcall(vim.keymap.del, 'n', keymap[1])
            local previous = saved_step_keymaps[keymap[1]]
            if previous then vim.fn.mapset('n', false, previous) end
          end
          saved_step_keymaps = nil
        end
      end)

      local function prompt_breakpoint(prompt, apply)
        local bufnr = vim.api.nvim_get_current_buf()
        local line = vim.api.nvim_win_get_cursor(0)[1]
        vim.ui.input({ prompt = prompt }, function(value)
          if value == nil then return end
          if not vim.api.nvim_buf_is_loaded(bufnr) or line > vim.api.nvim_buf_line_count(bufnr) then
            vim.notify('Breakpoint source is no longer available', vim.log.levels.WARN)
            return
          end
          -- The input UI may change the current buffer/window before returning.
          -- DAP's public breakpoint API operates on the current source line.
          vim.api.nvim_buf_call(bufnr, function()
            local view = vim.fn.winsaveview()
            vim.api.nvim_win_set_cursor(0, { line, 0 })
            local ok, err = pcall(apply, value)
            vim.fn.winrestview(view)
            if not ok then error(err) end
          end)
        end)
      end

      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, {
        desc = '[D]ebug: toggle [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dB', function()
        prompt_breakpoint('Breakpoint condition: ', function(value) dap.set_breakpoint(value) end)
      end, {
        desc = '[D]ebug: conditional [B]reakpoint',
      })

      vim.keymap.set('n', '<leader>dh', function()
        prompt_breakpoint('Hit condition (e.g. 10): ', function(value) dap.set_breakpoint(nil, value) end)
      end, {
        desc = '[D]ebug: breakpoint [H]it condition',
      })

      vim.keymap.set('n', '<leader>dl', function()
        prompt_breakpoint('Log message ({expression} is evaluated): ', function(value) dap.set_breakpoint(nil, nil, value) end)
      end, {
        desc = '[D]ebug: [L]og point',
      })

      vim.keymap.set('n', '<leader>dr', function()
        dapview.open()
        dapview.jump_to_view 'repl'
      end, {
        desc = '[D]ebug: open [R]EPL',
      })

      vim.keymap.set({ 'n', 'x' }, '<leader>de', function() dapview.hover(nil, false) end, {
        desc = '[D]ebug: [E]valuate expression (repeat to focus)',
      })

      vim.keymap.set({ 'n', 'x' }, '<leader>dw', dapview.add_expr, {
        desc = '[D]ebug: [W]atch expression',
      })

      vim.keymap.set('n', '<leader>dC', dap.run_to_cursor, {
        desc = '[D]ebug: run to [C]ursor',
      })

      vim.keymap.set('n', '<leader>dk', dap.up, {
        desc = '[D]ebug: stack up',
      })

      vim.keymap.set('n', '<leader>dj', dap.down, {
        desc = '[D]ebug: stack down',
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

      vim.keymap.set('n', '<leader>du', function() dapview.toggle(true) end, {
        desc = '[D]ebug: toggle [U]I',
      })

      vim.keymap.set('n', '<leader>dU', function() dapview.close(true) end, {
        desc = '[D]ebug: hide [U]I and console (keep session)',
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
