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

local function setup_output(bufnr, group)
    local task = require('overseer.task_list').get(vim.b[bufnr].overseer_task)
    if not task then return end

    local function close_output(stop)
        local win = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_config(win).relative == '' then return end
        if stop and task:is_running() then
            -- A picker would trigger Overseer's WinLeave handler and hide the float
            -- even on Cancel. Keep confirmation in this window and default to Cancel.
            if vim.fn.confirm(('Stop "%s"?\nUnsaved task changes may be lost.'):format(task.name), '&Stop\n&Cancel', 2) ~= 1 then return end
            task:stop()
        end
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then vim.api.nvim_win_close(win, true) end
    end

    -- These are Normal-mode controls; q/Q typed in Terminal-mode reach the task.
    vim.keymap.set('n', 'q', function() close_output(false) end, { buffer = bufnr, desc = 'Hide task output' })
    vim.keymap.set('n', 'Q', function() close_output(true) end, { buffer = bufnr, desc = 'Stop task and hide output' })

    vim.api.nvim_clear_autocmds { group = group, buffer = bufnr }
    if not task.metadata.interactive then return end
    -- Shadow both Escape sequences. Define the shorter mapping last so nowait
    -- wins over a partial match (:help :map-nowait).
    for _, key in ipairs { '<Esc><Esc>', '<Esc>' } do
        vim.keymap.set('t', key, key, { buffer = bufnr, nowait = true, desc = 'Send Escape to task' })
    end

    local function enter_terminal()
        local win = vim.api.nvim_get_current_win()
        vim.schedule(function()
            -- Do not steal focus from a picker/editor, or enter input for completed logs.
            if
                vim.api.nvim_get_current_win() == win
                and vim.api.nvim_get_current_buf() == bufnr
                and task:is_running()
                and vim.bo[bufnr].buftype == 'terminal'
            then
                vim.cmd.startinsert()
            end
        end)
    end
    vim.api.nvim_create_autocmd('BufEnter', { group = group, buffer = bufnr, callback = enter_terminal })
    -- The first float opens before Overseer assigns its output filetype.
    enter_terminal()
end

return {
    {
        'stevearc/overseer.nvim',
        -- Overseer lazy-loads its own internals. Staying eager keeps the
        -- nvim-dap `preLaunchTask` hook and every registered template available
        -- from the first `:OverseerRun`.
        lazy = false,
        -- Feature modules append templates and template hooks through merged opts.
        -- These are local extension lists, removed before Overseer's own setup.
        -- One config owner avoids competing init/config callbacks across features.
        opts_extend = { 'templates', 'template_hooks' },
        opts = {
            ---@type (overseer.TemplateFileDefinition|overseer.TemplateFileProvider)[]
            templates = {},
            ---@type { opts: overseer.HookOptions, hook: fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil) }[]
            template_hooks = {},
            form = { border = 'rounded' },
            task_win = { border = 'rounded' },
        },
        config = function(_, opts)
            local overseer = require 'overseer'
            local templates, template_hooks = opts.templates, opts.template_hooks
            opts.templates, opts.template_hooks = nil, nil
            overseer.setup(opts)
            for _, template in ipairs(templates) do
                overseer.register_template(template)
            end
            for _, hook in ipairs(template_hooks) do
                overseer.add_template_hook(hook.opts, hook.hook)
            end
            local group = vim.api.nvim_create_augroup('aakash-task-output', { clear = true })
            vim.api.nvim_create_autocmd('FileType', {
                group = group,
                pattern = 'OverseerOutput',
                desc = 'Set up task output controls and interactive input',
                callback = function(event) setup_output(event.buf, group) end,
            })
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
