-- ============================================================
-- TASKS
-- Overseer task runner: setup, task template registry, keymaps
-- ============================================================

local project = require 'aakash.project'

-- Pending tasks have no time_start. The task list groups parents/children,
-- so select by start time rather than its display order.
local function last_task()
  local root = project.get()
  local prefix = root:gsub('/$', '') .. '/'
  local latest
  for _, task in
    ipairs(require('overseer').list_tasks {
      filter = function(task)
        if not task.time_start then return false end
        local cwd = vim.fs.normalize(vim.uv.fs_realpath(task.cwd) or task.cwd)
        return cwd == root or vim.startswith(cwd, prefix)
      end,
    })
  do
    if not latest or task.time_start > latest.time_start then latest = task end
  end
  if not latest then vim.notify('No tasks have run in ' .. root, vim.log.levels.WARN) end
  return latest
end

return {
  {
    'stevearc/overseer.nvim',
    -- Overseer lazy-loads its own internals. Staying eager keeps the
    -- nvim-dap `preLaunchTask` hook and every registered template available
    -- from the first `:OverseerRun`.
    lazy = false,
    -- `templates` is not an Overseer option. Language modules append template
    -- definitions or providers to it through lazy.nvim's merged `opts`, and
    -- `config` registers them after setup. This mirrors the `servers`
    -- registry in `lsp.lua`: one setup path, extended per language.
    opts_extend = { 'templates' },
    opts = {
      ---@type (overseer.TemplateFileDefinition|overseer.TemplateFileProvider)[]
      templates = {},
      form = { border = 'rounded' },
      task_win = { border = 'rounded' },
    },
    config = function(_, opts)
      local overseer = require 'overseer'
      local templates = opts.templates
      opts.templates = nil
      overseer.setup(opts)
      for _, template in ipairs(templates) do
        overseer.register_template(template)
      end
    end,
    keys = {
      -- Native :OverseerRun searches from the buffer, :OverseerShell uses
      -- cwd, and the native task list/action interfaces remain global.
      {
        '<leader>bb',
        function()
          local root = project.get()
          require('overseer').run_task({
            search_params = { dir = root, filetype = vim.bo.filetype },
            on_build = function(task)
              -- Providers may deliberately choose a nested project cwd.
              task.cwd = task.cwd or root
            end,
          }, function(_, err)
            if err then vim.notify(err, vim.log.levels.ERROR) end
          end)
        end,
        desc = '[B]uild: run task',
      },
      { '<leader>bl', '<cmd>OverseerToggle<CR>', desc = '[B]uild: task [L]ist' },
      { '<leader>ba', '<cmd>OverseerTaskAction<CR>', desc = '[B]uild: task [A]ction' },
      {
        '<leader>bs',
        function()
          local root = project.get()
          vim.ui.input({ prompt = 'Command: ', completion = 'shellcmdline' }, function(cmd)
            if not cmd or cmd == '' then return end
            require('overseer').new_task({ cmd = cmd, cwd = root }):start()
          end)
        end,
        desc = '[B]uild: [S]hell command as task',
      },
      {
        '<leader>br',
        function()
          local task = last_task()
          if task then require('overseer').run_action(task, 'restart') end
        end,
        desc = '[B]uild: [R]estart last task',
      },
      {
        '<leader>bo',
        function()
          local task = last_task()
          if task then task:open_output 'float' end
        end,
        desc = '[B]uild: last task [O]utput',
      },
    },
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>b', group = '[B]uild tasks' })
    end,
  },
}
