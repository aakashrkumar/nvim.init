-- ============================================================
-- PROFILING
-- Local captures and viewers use the existing Overseer task UI
-- ============================================================

local linux = vim.uv.os_uname().sysname == 'Linux'

return {
  {
    'stevearc/overseer.nvim',
    -- tasks.lua owns setup; this feature only extends its template registry.
    opts = function(_, opts)
      opts.templates = opts.templates or {}
      table.insert(opts.templates, require('aakash.performance').program)
    end,
    init = function()
      vim.api.nvim_create_user_command('Profile', function() require('aakash.performance').run() end, { desc = 'Profile a local program' })
      vim.api.nvim_create_user_command(
        'ProfileRepeat',
        function() require('aakash.performance').repeat_last() end,
        { desc = 'Repeat this project’s last profile' }
      )
      vim.api.nvim_create_user_command('ProfileOpen', function() require('aakash.performance').open() end, { desc = 'Open this project’s last profile' })
    end,
    -- :Profile reviews every setting in Snacks before Run. Arguments and environment
    -- variables have entry editors; Cancel leaves no task. Overseer owns execution.
    -- Rust launches expect a manifest profiling profile with release optimization
    -- and debug symbols. Use terminal Ctrl-C to let a profiler finish writing;
    -- Overseer Stop cancels the task. Keep the viewer task alive for its browser.
    keys = {
      { '<leader>Pp', '<cmd>Profile<cr>', desc = '[P]rofile program' },
      { '<leader>Pr', '<cmd>ProfileRepeat<cr>', desc = '[R]epeat profile' },
      { '<leader>Po', '<cmd>ProfileOpen<cr>', desc = '[O]pen profile' },
    },
  },

  {
    't-troebst/perfanno.nvim',
    enabled = linux,
    cmd = {
      'PerfLoadFlat',
      'PerfLoadCallGraph',
      'PerfLoadFlameGraph',
      'PerfLuaProfileStart',
      'PerfLuaProfileStop',
      'PerfCacheSave',
      'PerfCacheLoad',
      'PerfCacheDelete',
      'PerfPickEvent',
      'PerfCycleFormat',
      'PerfAnnotate',
      'PerfToggleAnnotations',
      'PerfAnnotateFunction',
      'PerfAnnotateSelection',
      'PerfHottestSymbols',
      'PerfHottestLines',
      'PerfHottestCallersFunction',
      'PerfHottestCallersSelection',
    },
    opts = function()
      -- Keep native parsing/counting and picker defaults (vim.ui.select fallback).
      return { get_path_callback = require('aakash.performance').perf_file }
    end,
    -- Flat samples are self cost; callgraph samples include nested callees.
    -- Callers require the latter; loading it can take longer than the flat view.
    keys = {
      { '<leader>Plf', function() require('aakash.performance').load_perf 'flat' end, desc = 'Load [F]lat profile (self)' },
      { '<leader>Plg', function() require('aakash.performance').load_perf 'callgraph' end, desc = 'Load call[G]raph (inclusive)' },
      { '<leader>Pt', '<cmd>PerfToggleAnnotations<cr>', desc = '[T]oggle profile annotations' },
      { '<leader>Ph', '<cmd>PerfHottestLines<cr>', desc = '[H]ottest lines' },
      { '<leader>Pc', '<cmd>PerfHottestCallersFunction<cr>', desc = 'Hottest [C]allers' },
      { '<leader>Pc', ':PerfHottestCallersSelection<cr>', mode = 'x', desc = 'Hottest [C]allers of selection' },
    },
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>P', group = '[P]rofile' })
      if linux then table.insert(opts.spec, { '<leader>Pl', group = '[L]oad perf data' }) end
    end,
  },
}
