-- [[ Cargo firmware and device ownership ]]
-- Cargo resolves toolchains, targets and runners. Metadata identifies ESP crates
-- without parsing Cargo configuration, fetching dependencies or changing a lockfile.
local M = {}

local function cargo_options(argv)
    local options = { metadata = { argv and argv[1] or 'cargo', 'metadata', '--no-deps', '--offline', '--locked', '--format-version', '1' }, packages = {} }
    local i = 2
    if argv and argv[i] and argv[i]:sub(1, 1) == '+' then
        table.insert(options.metadata, 2, argv[i])
        i = i + 1
    end
    while argv and i <= #argv do
        local arg = argv[i]
        if arg == '--' then break end
        local key, value = arg:match '^(%-%-[^=]+)=(.*)$'
        key = key or arg
        if key == '--manifest-path' or key == '--config' or key == '--package' or key == '-p' or key == '--target' then
            if not value then
                i = i + 1
                value = argv[i]
            end
            if value then
                if key == '--manifest-path' or key == '--config' then
                    vim.list_extend(options.metadata, { key, value })
                elseif key == '--target' then
                    options.target = value
                else
                    table.insert(options.packages, value)
                end
            end
        elseif key == '--no-run' then
            options.no_run = true
        elseif not options.command and arg:sub(1, 1) ~= '-' then
            options.command = arg
        end
        i = i + 1
    end
    return options
end

---@param dir string
---@param argv? string[] Cargo command, including its executable
---@param env? table<string, string>
---@return table? context
---@return string? error
function M.project(dir, argv, env)
    if not dir or not vim.fs.root(dir, 'Cargo.toml') then return end
    local options = cargo_options(argv)
    if vim.fn.executable(options.metadata[1]) ~= 1 then return nil, 'Cargo is not on PATH; install the project’s Rust toolchain.' end
    local inspection_env = vim.tbl_extend('force', env or {}, { RUSTUP_AUTO_INSTALL = '0' })
    local result = vim.system(options.metadata, { cwd = dir, env = inspection_env, text = true }):wait(5000)
    if result.code ~= 0 then return nil, 'Cargo metadata: ' .. vim.trim(result.stderr or 'command failed') end
    local ok, metadata = pcall(vim.json.decode, result.stdout)
    if not ok then return nil, 'Cargo metadata: ' .. tostring(metadata) end

    local sdk
    for _, package in ipairs(metadata.packages) do
        local selected = #options.packages == 0
        for _, spec in ipairs(options.packages) do
            if spec == package.id or spec:match '^[^@:]+' == package.name then selected = true end
        end
        if selected then
            for _, dependency in ipairs(package.dependencies) do
                if dependency.name == 'esp-idf-sys' or dependency.name == 'esp-idf-hal' or dependency.name == 'esp-idf-svc' then
                    sdk = 'idf'
                elseif dependency.name == 'esp-hal' and not sdk then
                    sdk = 'hal'
                end
            end
        end
    end
    if not sdk then return end
    local settings = require('aakash.rust').settings(metadata.workspace_root, {})
    return {
        root = metadata.workspace_root,
        cwd = dir,
        sdk = sdk,
        packages = metadata.packages,
        target = options.target or (env and env.CARGO_BUILD_TARGET) or vim.env.CARGO_BUILD_TARGET or vim.tbl_get(settings, 'rust-analyzer', 'cargo', 'target'),
        settings = settings['rust-analyzer'] or {},
    }
end

local function uses_probe(resource) return resource == 'probe' or resource == 'device' or (resource and vim.startswith(resource, 'openocd:')) end

-- These are conservative resources within this Neovim, not OS/per-device locks.
-- UART monitoring can coexist with JTAG; an opaque Cargo runner claims either.
function M.same_resource(a, b)
    local left, right = a.metadata.esp_resource, b.metadata.esp_resource
    if not left or not right then return false end
    return left == right or left == 'device' or right == 'device' or (uses_probe(left) and uses_probe(right)) or false
end

function M.probe_available()
    local dap = package.loaded.dap
    if dap then
        for _, session in pairs(dap.sessions()) do
            if session.config.type == 'probe-rs-debug' then
                return false, 'Stop the active probe-rs debugger (<leader>dt) before starting another device task.'
            end
        end
    end
    return true
end

function M.can_start(resource)
    if uses_probe(resource) then return M.probe_available() end
    return true
end

function M.stop_tasks(resource)
    local owner = { metadata = { esp_resource = resource } }
    for _, task in ipairs(require('overseer').list_tasks()) do
        if M.same_resource(task, owner) then task:dispose(true) end
    end
end

local function replace_resource(a, b)
    -- Overseer dispatches every pre-start callback even after a veto. Do not
    -- dispose another task when the DAP guard is going to prevent this start.
    return M.can_start(b.metadata.esp_resource) and M.same_resource(a, b)
end

---@param task table overseer.TaskDefinition
---@param resource? string
---@param interactive? boolean
---@return table
function M.resource_task(task, resource, interactive)
    task.metadata = task.metadata or {}
    task.metadata.esp_resource = resource
    task.metadata.interactive = interactive
    task.components = task.components or { 'default' }
    if resource then
        table.insert(task.components, 'aakash.esp_resource')
        table.insert(task.components, { 'unique', compare = replace_resource })
    end
    if interactive then
        local output = { 'open_output', direction = 'float', focus = true, on_start = 'always' }
        local replaced = false
        for i, component in ipairs(task.components) do
            if (type(component) == 'table' and component[1] or component) == 'open_output' then
                task.components[i] = output
                replaced = true
            end
        end
        if not replaced then table.insert(task.components, output) end
    end
    return task
end

---@param task table overseer.TaskDefinition
---@return table
function M.cargo_task(task)
    if type(task.cmd) ~= 'table' or vim.fs.basename(task.cmd[1]) ~= 'cargo' then return task end
    local options = cargo_options(task.cmd)
    if options.no_run or not vim.tbl_contains({ 'run', 'test', 'bench' }, options.command) then return task end
    local project, err = M.project(task.cwd, task.cmd, task.env)
    if err then error(err, 0) end
    if project then return M.resource_task(task, 'device', true) end
    return task
end

return M
