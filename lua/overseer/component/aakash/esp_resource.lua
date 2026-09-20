-- DAP sessions are not Overseer tasks. Let native `unique` handle task
-- replacement, but never take a probe from a live debugger.
return {
    desc = 'Keep firmware tasks from taking an active debugger’s probe',
    editable = false,
    constructor = function()
        return {
            on_pre_start = function(_, task)
                local available, reason = require('aakash.esp32').can_start(task.metadata.esp_resource)
                if not available then
                    vim.notify(reason, vim.log.levels.WARN)
                    return false
                end
            end,
        }
    end,
}
