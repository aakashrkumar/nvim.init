-- [[ Rust analysis ]]
-- Use stable rust-analyzer without changing Cargo's project-selected toolchain.
-- Project settings belong to their Cargo root, not the current buffer or cwd.

local M = {}
local analyzer_path
local switching = false
local displaced = {}

local function normalize(path)
    if not path or path == '' then return nil end
    path = vim.fn.fnamemodify(path, ':p')
    return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

function M.analyzer_command()
    if not analyzer_path then
        local rustup = vim.fn.exepath 'rustup'
        if rustup == '' then error('Rust analysis requires rustup on PATH and the stable rust-analyzer component.', 0) end
        local result = vim.system({ rustup, 'which', '--toolchain', 'stable', 'rust-analyzer' }, {
            text = true,
            env = { RUSTUP_AUTO_INSTALL = '0' },
        }):wait(10000)
        local path = result.code == 0 and vim.trim(result.stdout or '') or nil
        if not path or path == '' or vim.fn.executable(path) ~= 1 then
            error('Stable rust-analyzer is unavailable. Run `rustup component add --toolchain stable rust-analyzer`.\n' .. vim.trim(result.stderr or ''), 0)
        end
        analyzer_path = path
    end
    return { analyzer_path }
end

function M.settings(root, defaults)
    local settings = vim.deepcopy(defaults or {})
    root = normalize(root)
    if not root then return settings end

    -- The loader and interpolation extension each have their own root override.
    -- Neither may consult a buffer focused after asynchronous root discovery.
    return require('codesettings')
        .loader()
        :root_dir(root)
        :config_file_paths({ '.vscode/settings.json' })
        :merge_lists('replace')
        :loader_extensions({ require 'codesettings.extensions.vscode' { root = root } })
        :with_local_settings('rust-analyzer', { settings = settings }).settings
end

local function stop_for_switch(client)
    for bufnr in pairs(client.attached_buffers) do
        displaced[bufnr] = true
    end
    if not client:is_stopped() then client:stop() end
end

function M.server_settings(root, defaults)
    local settings = M.settings(root, defaults)
    root = normalize(root)
    local stopping = {}
    for _, client in ipairs(vim.lsp.get_clients { name = 'rust-analyzer' }) do
        if normalize(client.config.root_dir) ~= root then
            stopping[#stopping + 1] = client.id
            stop_for_switch(client)
        end
    end
    if #stopping == 0 then return settings end

    -- One active analyzer root prevents project target/feature settings leaking.
    -- Rustaceanvim 9 adds a different root to an existing client before calling
    -- reuse_client. Stop it through the public lifecycle and wait for removal:
    -- get_clients still returns a stopped client until its exit callback runs.
    switching = true
    local stopped = vim.wait(5000, function()
        for _, id in ipairs(stopping) do
            if vim.lsp.get_client_by_id(id) then return false end
        end
        return true
    end, 10)
    switching = false
    if not stopped then error('rust-analyzer is still stopping for another project. Retry :RustAnalyzer start after it exits.', 0) end
    return settings
end

function M.reuse_client(client, config)
    if client.name ~= config.name or client:is_stopped() then return false end
    if normalize(client.config.root_dir) == normalize(config.root_dir) then return true end
    -- Neovim hides uninitialized clients from get_clients. This public callback
    -- also sees those clients, so fast root switches cannot reuse or retain one.
    stop_for_switch(client)
    return false
end

function M.setup()
    local scheduled = false
    local function attach_current()
        if scheduled then return end
        scheduled = true
        vim.schedule(function()
            scheduled = false
            if switching then return end
            local bufnr = vim.api.nvim_get_current_buf()
            if not displaced[bufnr] then return end
            if vim.bo[bufnr].filetype ~= 'rust' or vim.bo[bufnr].buftype ~= '' or vim.api.nvim_buf_get_name(bufnr) == '' then return end
            for _, client in ipairs(vim.lsp.get_clients { name = 'rust-analyzer', bufnr = bufnr }) do
                if not client:is_stopped() then
                    displaced[bufnr] = nil
                    return
                end
            end
            local ok, err = pcall(require('rustaceanvim.lsp').start, bufnr)
            if not ok then vim.notify(err, vim.log.levels.ERROR) end
        end)
    end

    -- Rustaceanvim still owns initial attachment and manual start/stop. Revive
    -- only buffers detached by our root switch, never a manually stopped client.
    local group = vim.api.nvim_create_augroup('aakash-rust-project', { clear = true })
    vim.api.nvim_create_autocmd('BufEnter', { group = group, callback = attach_current })
    vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(event)
            local client = vim.lsp.get_client_by_id(event.data.client_id)
            if client and client.name == 'rust-analyzer' then attach_current() end
        end,
    })
    vim.api.nvim_create_autocmd('BufWipeout', {
        group = group,
        callback = function(event) displaced[event.buf] = nil end,
    })
end

return M
