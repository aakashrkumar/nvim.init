-- [[ Project diagnostics ]]
-- Native diagnostics own the messages; Trouble displays the project list.
-- MiniStatusline reads cached counts, so redrawing never scans diagnostics.
-- See `:help vim.diagnostic` and `:help trouble.nvim`.

local project = require 'aakash.project'
local M = {}

-- Keep diagnostic collection out of statusline redraws. Unloaded buffers count
-- too: language servers can publish diagnostics for files we have never opened.
local buffers, tabs, dirty = {}, {}, {}
local pending, root_pending, initialized = false, false, false
local content = ''
local click = "@v:lua.require'aakash.diagnostics'.click@"
local levels = {
    { name = 'Error', icon = '', letter = 'E' },
    { name = 'Warn', icon = '', letter = 'W' },
    { name = 'Info', icon = '', letter = 'I' },
    { name = 'Hint', icon = '󰌵', letter = 'H' },
}

local function buffer_info(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return nil end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == '' then return nil end
    local info = buffers[buf]
    if not info or info.name ~= name then
        info = { name = name, path = vim.fs.normalize(vim.uv.fs_realpath(name) or name), counts = {} }
        buffers[buf] = info
    end
    return info
end

local function inside(root, path)
    local prefix = root:sub(-1) == '/' and root or root .. '/'
    return path == root or path:sub(1, #prefix) == prefix
end

local function filter_project(view, root)
    view:filter({
        function(item)
            local info = item.buf and buffer_info(item.buf)
            return info ~= nil and inside(root, info.path)
        end,
    }, { id = 'project', template = '{hl:Title}Project:{hl} {root}', data = { root = root } })
end

local function render()
    local state = tabs[vim.api.nvim_get_current_tabpage()]
    local counts = { 0, 0, 0, 0 }
    for _, info in pairs(buffers) do
        if state and inside(state.root, info.path) then
            for severity, count in pairs(info.counts) do
                counts[severity] = counts[severity] + count
            end
        end
    end

    local parts = { '%#MiniStatuslineFileinfo#%0' .. click .. 'Project%X' }
    for severity, level in ipairs(levels) do
        local highlight = 'ProjectDiagnostic' .. (counts[severity] == 0 and 'Zero' or level.name)
        local icon = vim.g.have_nerd_font and level.icon or level.letter
        parts[#parts + 1] = ('%%#%s#%%%d%s%s %d%%X'):format(highlight, severity, click, icon, counts[severity])
    end
    content = table.concat(parts, ' ') .. '%#MiniStatuslineFileinfo#'
    vim.cmd.redrawstatus()
end

local function current_project()
    local tab = vim.api.nvim_get_current_tabpage()
    local state = tabs[tab]
    if not state then
        state = {}
        tabs[tab] = state
    end

    local root = project.get()
    if state.root ~= root then
        state.root = root
        if state.view and state.view:is_open() then filter_project(state.view, root) end
    end
    render()
    return state
end

local function queue_project()
    if root_pending then return end
    root_pending = true
    -- Buffer APIs can fire events inside a temporary autocmd window. Resolve
    -- the real focused project's root after that context (or LspDetach) ends.
    vim.schedule(function()
        root_pending = false
        current_project()
    end)
end

local function refresh_buffers()
    pending = false
    for buf in pairs(dirty) do
        local info = buffer_info(buf)
        if info then info.counts = vim.diagnostic.count(buf) end
    end
    dirty = {}
    render()
end

local function queue_buffer(event)
    dirty[event.buf] = true
    if pending then return end
    pending = true
    -- Coalesce workspace publications without delaying updates indefinitely
    -- when a server sends diagnostics continuously.
    vim.defer_fn(refresh_buffers, 50)
end

local function highlights()
    local background = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineFileinfo', link = false }).bg
    for _, level in ipairs(levels) do
        local foreground = vim.api.nvim_get_hl(0, { name = 'Diagnostic' .. level.name, link = false }).fg
        vim.api.nvim_set_hl(0, 'ProjectDiagnostic' .. level.name, { fg = foreground, bg = background })
    end
    local muted = vim.api.nvim_get_hl(0, { name = 'Comment', link = false }).fg
    vim.api.nvim_set_hl(0, 'ProjectDiagnosticZero', { fg = muted, bg = background })
end

function M.setup()
    if initialized then return end
    initialized = true

    local group = vim.api.nvim_create_augroup('aakash-project-diagnostics', { clear = true })
    vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'BufFilePost' }, { group = group, callback = queue_buffer })
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = group,
        callback = function(event)
            buffers[event.buf], dirty[event.buf] = nil, nil
            render()
        end,
    })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufFilePost', 'DirChanged', 'TabEnter', 'LspAttach', 'LspDetach' }, {
        group = group,
        callback = queue_project,
    })
    vim.api.nvim_create_autocmd('TabClosed', {
        group = group,
        callback = function()
            for tab in pairs(tabs) do
                if not vim.api.nvim_tabpage_is_valid(tab) then tabs[tab] = nil end
            end
        end,
    })
    vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local info = buffer_info(buf)
        if info then info.counts = vim.diagnostic.count(buf) end
    end
    highlights()
    current_project()
end

-- Mini calls this on every redraw; only return the already formatted section.
function M.section() return content end

function M.open(severity)
    local state = current_project()
    local tab = vim.api.nvim_get_current_tabpage()
    local view = state.view
    if not view or not (view:is_open() or view.first_update:is_pending()) then
        -- Trouble's default lookup is session-wide. Own one view per tab so
        -- clicking a counter never focuses another project's tab.
        view = require('trouble').open { mode = 'project_diagnostics', new = true, focus = false }
        state.view = view
    end
    filter_project(view, state.root)
    view:filter({ severity = severity }, { id = 'severity', template = '{hl:Title}Severity:{hl} {severity}', del = severity == nil })
    -- A counter opens that severity across the project, not a previously
    -- selected buffer-only subset from Trouble's `gb` action.
    view:filter({ buf = 0 }, { id = vim.inspect { buf = 0 }, del = true })
    -- A newly created view has not mounted yet, so ordinary filter refreshes
    -- are skipped. Apply them before its first render, not on a later event.
    if not view:is_open() then view:refresh { opening = true } end
    view:wait(function()
        if state.view == view and vim.api.nvim_get_current_tabpage() == tab and view:is_open() then view.win:focus() end
    end)
end

function M.toggle()
    local state = current_project()
    local view = state.view
    if view and (view:is_open() or view.first_update:is_pending()) then
        state.view = nil
        view:close()
        -- A second toggle can arrive before Trouble mounts its first window.
        view:wait(function() view:close() end)
    else
        M.open()
    end
end

function M.click(severity, _, button)
    if button ~= 'l' then return end
    -- Native statusline click callbacks should not change windows directly.
    vim.schedule(function() M.open(severity ~= 0 and severity or nil) end)
end

return M
