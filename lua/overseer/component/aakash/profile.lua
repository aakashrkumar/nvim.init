-- [[ Profiling task lifecycle ]]
-- Save source before recording and require a real capture before success.
-- Also prevent overlapping captures and open PerfAnno or Instruments on success.
-- Overseer's built-in components handle retention, uniqueness, and Samply viewers.
return {
    desc = 'Prepare and validate a local profiling capture, then open its viewer',
    editable = false,
    constructor = function()
        return {
            on_reset = function(_, task)
                local profile = task.metadata.profile
                if profile.backend ~= 'instruments' then return end
                -- Instruments caches open documents. A fresh bundle keeps both the
                -- previous document and the new recording usable without UI automation.
                for i, arg in ipairs(task.cmd) do
                    if arg == '--output' and task.cmd[i + 1] == profile.file then
                        profile.file = require('aakash.performance').artifact_path(profile.root, profile.backend)
                        task.cmd[i + 1] = profile.file
                        return
                    end
                end
                error 'Cannot locate this task’s Instruments output argument'
            end,
            on_pre_start = function(self, task)
                local profile = task.metadata.profile
                profile.ready = false
                for _, other in ipairs(require('overseer').list_tasks()) do
                    if other ~= task and other:is_running() and other.metadata.profile and other.metadata.profile.root == profile.root then
                        vim.notify('This project is already being profiled; stop or finish its capture first', vim.log.levels.WARN)
                        return false
                    end
                end

                local modified = {}
                local prefix = profile.root:gsub('/$', '') .. '/'
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' and vim.bo[buf].modified then
                        local path = vim.api.nvim_buf_get_name(buf)
                        path = vim.fs.normalize(vim.uv.fs_realpath(path) or path)
                        if path == profile.root or vim.startswith(path, prefix) then table.insert(modified, buf) end
                    end
                end
                if #modified > 0 then
                    if not self.prompting then
                        self.prompting = true
                        vim.ui.select({ 'Save and profile', 'Cancel' }, { prompt = 'Profiling needs saved project files' }, function(choice)
                            self.prompting = false
                            if choice ~= 'Save and profile' or task:is_disposed() then return end
                            local ok, err = pcall(function()
                                for _, buf in ipairs(modified) do
                                    vim.api.nvim_buf_call(buf, function() vim.cmd.update() end)
                                end
                            end)
                            if ok then
                                task:start()
                            else
                                vim.notify(tostring(err), vim.log.levels.ERROR)
                            end
                        end)
                    end
                    return false
                end

                local ok, err = pcall(function()
                    vim.fn.mkdir(vim.fs.dirname(profile.file), 'p')
                    -- Samply/perf repeat in place; Instruments resets to a fresh path.
                    -- A failed recording must never reuse an older successful capture.
                    local stat = vim.uv.fs_lstat(profile.file)
                    if stat then
                        if profile.backend == 'instruments' then
                            error 'Instruments trace already exists; restart this task to record a new trace'
                        else
                            local removed, reason = os.remove(profile.file)
                            if not removed then error(reason, 0) end
                        end
                    end
                end)
                if not ok then
                    vim.notify(tostring(err), vim.log.levels.ERROR)
                    return false
                end
                profile.ready = true
            end,
            on_start = function(_, task)
                vim.notify('Started ' .. task.name .. '\n:ProfileOutput toggles its output', vim.log.levels.INFO, { title = 'Profiling' })
            end,
            on_exit = function(_, task, code)
                local status = code == 0 and 'SUCCESS' or 'FAILURE'
                if status == 'SUCCESS' then
                    local profile = task.metadata.profile
                    if not require('aakash.performance').artifact_stat(profile.file, profile.backend) then
                        local message = 'No valid capture was written; see :ProfileOutput for build or recording errors.'
                        task:set_result { error = message }
                        vim.notify(message, vim.log.levels.ERROR)
                        status = 'FAILURE'
                    end
                end
                task:finalize(status)
            end,
            on_complete = function(_, task, status)
                if status ~= 'SUCCESS' then return end
                local profile = task.metadata.profile
                local file = profile.file
                if profile.backend == 'perf' then
                    vim.schedule(function() require('aakash.performance').load_perf('flat', file) end)
                elseif profile.backend == 'instruments' then
                    -- A timed recording can be usable even when Cargo skips its open step.
                    vim.schedule(function()
                        local _, err = vim.ui.open(file)
                        if err then vim.notify(err, vim.log.levels.ERROR) end
                    end)
                end
            end,
        }
    end,
}
