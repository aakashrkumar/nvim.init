-- [[ Project roots ]]
-- Searches, navigation, diagnostics, and tasks share one project policy.
-- An explicit tab root wins. Otherwise use the source buffer's LSP workspace,
-- nearest marker, or directory. Tool windows keep the last source project.
-- See `:help :tcd` and `:help vim.fs.find()`.

local M = {}

-- Remember one source buffer per tab, not a separate project registry.
-- Retain its last root if the buffer is deleted while a tool window is open.
local sources = {}

-- Markers are fallbacks for files without an attached language server.
M.patterns = {
    'Cargo.toml',
    'rust-project.json',
    'pyrightconfig.json',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'mvnw',
    'gradlew',
    'settings.gradle',
    'settings.gradle.kts',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'build.xml',
    '.clangd',
    'compile_commands.json',
    'CMakePresets.json',
    'sdkconfig',
    'sdkconfig.defaults',
    'platformio.ini',
    '.luarc.json',
    '.luarc.jsonc',
    'lua',
    '.obsidian',
    '.git',
}

local function normalize(path)
    if not path or path == '' then return nil end
    path = vim.fn.fnamemodify(path, ':p')
    return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local function contains(root, path)
    if root == path then return true end
    local prefix = root:sub(-1) == '/' and root or root .. '/'
    return path:sub(1, #prefix) == prefix
end

local function buffer_path(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return nil end
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match '^%a[%w+.-]*://' then return nil end
    return normalize(name)
end

local function lsp_roots(buf, path)
    local roots = {}
    for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
        if client.root_dir then roots[#roots + 1] = client.root_dir end
        for _, workspace in ipairs(client.workspace_folders or client.config.workspace_folders or {}) do
            roots[#roots + 1] = workspace.uri and vim.uri_to_fname(workspace.uri) or workspace.name
        end
    end

    local found = {}
    for _, root in ipairs(roots) do
        root = normalize(root)
        if root and contains(root, path) and not vim.tbl_contains(found, root) then found[#found + 1] = root end
    end
    table.sort(found, function(left, right) return #left > #right end)
    return found
end

local function detect_source(buf, path)
    local roots = lsp_roots(buf, path)
    if roots[1] then return roots[1], 'lsp' end

    local marker = vim.fs.find(M.patterns, { path = path, upward = true })[1]
    if marker then return normalize(vim.fs.dirname(marker)), 'marker' end

    local stat = vim.uv.fs_stat(path)
    return stat and stat.type == 'directory' and path or vim.fs.dirname(path), 'file'
end

-- Detect without the explicit tab override, so `:ProjectRoot!` can adopt
-- another source project. Inside tools, use the tab's last source buffer.
---@param buf? integer
---@return string root
---@return string source
function M.detect(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
    local tab = vim.api.nvim_get_current_tabpage()
    local path = buffer_path(buf)
    if path then
        local root, source = detect_source(buf, path)
        -- Temporary autocmd windows must not become the tab's source context.
        if buf == vim.api.nvim_get_current_buf() and vim.fn.win_gettype() ~= 'autocmd' then sources[tab] = { buf = buf, root = root, source = source } end
        return root, source
    end

    local previous = sources[tab]
    if previous then
        local previous_path = buffer_path(previous.buf)
        if previous_path then
            -- Resolve again for renames and LSP attach/detach while a tool is focused.
            previous.root, previous.source = detect_source(previous.buf, previous_path)
        end
        return previous.root, 'last source (' .. previous.source .. ')'
    end
    return normalize(vim.fn.getcwd(-1, 0)), 'cwd'
end

function M.get()
    if vim.fn.haslocaldir(-1, 0) == 1 then return normalize(vim.fn.getcwd(-1, 0)) end
    local root = M.detect()
    return root
end

function M.set(path, notify)
    local root = normalize(path)
    local stat = root and vim.uv.fs_stat(root)
    if not stat or stat.type ~= 'directory' then
        vim.notify(('Cannot use project root: %s'):format(path or ''), vim.log.levels.ERROR)
        return false
    end

    local ok, err = pcall(vim.fn.chdir, root, 'tabpage')
    if not ok then
        vim.notify(('Cannot change project root to %s: %s'):format(root, err), vim.log.levels.ERROR)
        return false
    end
    if notify then vim.notify(('Project: %s'):format(root)) end
    return true
end

function M.use_current()
    local root = M.detect()
    return M.set(root, true)
end

function M.info()
    if vim.fn.haslocaldir(-1, 0) == 1 then
        vim.notify(('Root: %s\nSource: tab'):format(M.get()))
        return
    end

    local root, source = M.detect()
    vim.notify(('Root: %s\nSource: %s'):format(root, source))
end

function M.setup()
    local group = vim.api.nvim_create_augroup('aakash-project-root', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufFilePost', 'TabEnter' }, {
        group = group,
        desc = 'Remember the source project before entering a tool window',
        callback = function(event)
            if event.buf == vim.api.nvim_get_current_buf() and vim.fn.win_gettype() ~= 'autocmd' then M.detect(event.buf) end
        end,
    })
    vim.api.nvim_create_autocmd('TabClosed', {
        group = group,
        callback = function()
            for tab in pairs(sources) do
                if not vim.api.nvim_tabpage_is_valid(tab) then sources[tab] = nil end
            end
        end,
    })
    M.detect()

    vim.api.nvim_create_user_command('ProjectRoot', function(command)
        if command.bang then
            M.use_current()
        elseif command.args ~= '' then
            M.set(command.args, true)
        else
            M.info()
        end
    end, { nargs = '?', bang = true, complete = 'dir', desc = 'Inspect or set the current tab project root' })
end

return M
