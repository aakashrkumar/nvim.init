-- Save source before recording and require a real capture before success.
-- Also prevent overlapping captures and load native PerfAnno on Linux.
-- Overseer's built-in components handle retention, uniqueness, and viewers.
return {
  desc = 'Prepare and validate a local profiling capture, then load PerfAnno',
  editable = false,
  constructor = function()
    return {
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
          -- Repeat replaces this task's own artifact. Removing it first means
          -- a failed build cannot be mistaken for a new successful capture.
          if vim.uv.fs_lstat(profile.file) then
            local removed, reason = os.remove(profile.file)
            if not removed then error(reason, 0) end
          end
        end)
        if not ok then
          vim.notify(tostring(err), vim.log.levels.ERROR)
          return false
        end
        profile.ready = true
      end,
      on_exit = function(_, task, code)
        local status = code == 0 and 'SUCCESS' or 'FAILURE'
        if status == 'SUCCESS' then
          local stat = vim.uv.fs_stat(task.metadata.profile.file)
          if not stat or stat.type ~= 'file' or stat.size == 0 then
            local message = 'No capture was written; check whether a build target or runner override bypassed the profiler.'
            task:set_result { error = message }
            vim.notify(message, vim.log.levels.ERROR)
            status = 'FAILURE'
          end
        end
        task:finalize(status)
      end,
      on_complete = function(_, task, status)
        local profile = task.metadata.profile
        if status == 'SUCCESS' and profile.backend == 'perf' then vim.schedule(function() require('aakash.performance').load_perf('flat', profile.file) end) end
      end,
    }
  end,
}
