-- [[ Rust firmware debugging ]]
-- Rustaceanvim builds the selected runnable; launch.json owns the board, probe,
-- flashing policy and RTT settings. Native Rust keeps its CodeLLDB setup.
local M = {}
local adapter_type = 'probe-rs-debug'

local function absolute(path) return type(path) == 'string' and (path:sub(1, 1) == '/' or path:match '^%a:[/\\]' ~= nil or path:match '^\\\\' ~= nil) end

M.rust_configuration = {
    name = 'Rust debug client',
    type = 'codelldb',
    request = 'launch',
    stopOnEntry = false,
    sourceLanguages = { 'rust' },
    aakash_rust = true,
}

M.type_to_filetypes = { [adapter_type] = { 'rust' } }

local function notify(message) vim.notify('ESP32 debug: ' .. message, vim.log.levels.ERROR) end

local function abort(config, message)
    if message then notify(message) end
    -- nvim-dap checks top-level values, not a returned ABORT table or a nested
    -- coreConfigs entry. Keep the sentinel intact through native expansion.
    return { name = config.name or 'ESP32 debug', type = adapter_type, request = config.request or 'launch', aakash_abort = require('dap').ABORT }
end

-- A workspace can contain both host tools and firmware. Inspect only the known
-- compiled artifact's ELF identification/machine fields; do not discover Cargo
-- artifacts or infer a chip from the machine architecture.
local function embedded_artifact(path)
    local file, open_error = io.open(path, 'rb')
    if not file then return nil, ('Cannot inspect compiled artifact %s: %s'):format(path, open_error) end
    local header, read_error = file:read(20)
    file:close()
    if not header or #header < 20 then
        return nil, ('Cannot read compiled artifact header %s: %s'):format(path, read_error or 'file is shorter than 20 bytes')
    end
    if header:sub(1, 4) ~= '\127ELF' then return false end
    local class, encoding = header:byte(5, 6)
    if (class ~= 1 and class ~= 2) or (encoding ~= 1 and encoding ~= 2) then
        return nil, ('Invalid ELF class or byte order in compiled artifact %s'):format(path)
    end
    local first, second = header:byte(19, 20)
    local machine = encoding == 1 and first + second * 256 or first * 256 + second
    return class == 1 and (machine == 243 or machine == 94) -- EM_RISCV / EM_XTENSA
end

local function launch_configs(root)
    local path = vim.fs.joinpath(root, '.vscode', 'launch.json')
    local ok, configs = pcall(require('dap.ext.vscode').getconfigs, path)
    if not ok then return nil, ('Cannot load %s: %s'):format(path, configs) end
    return configs
end

-- Bind workspace variables before a picker/input can change the active tab.
-- Buffer-derived variables cannot identify a runnable's source after its async
-- build, so reject them rather than choosing a different project's chip/ELF.
local function bind_workspace(value, root)
    if value == require('dap').ABORT then return nil, require('dap').ABORT end
    if type(value) == 'table' then
        local result = {}
        for key, item in pairs(value) do
            local bound_key, key_error = bind_workspace(key, root)
            if key_error then return nil, key_error end
            local bound_item, item_error = bind_workspace(item, root)
            if item_error then return nil, item_error end
            result[bound_key] = bound_item
        end
        return result
    end
    if type(value) ~= 'string' then return value end
    if value:find '%${file[^}]*}' or value:find '%${relativeFile[^}]*}' then
        return nil,
            'Buffer-relative launch variables are unsafe after an asynchronous build or picker. Use ${workspaceFolder}, ${env:NAME}, ${input:id}, or an explicit value in launch.json.'
    end
    if value:find '%${workspaceFolder:[^}]+}' then
        return nil,
            'Named workspace variables cannot be resolved from this launch.json alone. Use ${workspaceFolder} or an explicit path in the firmware project.'
    end
    value = value:gsub('%${workspaceFolder}', function() return root end)
    value = value:gsub('%${workspaceRoot}', function() return root end)
    value = value:gsub('%${cwd}', function() return root end)
    value = value:gsub('%${workspaceFolderBasename}', function() return vim.fs.basename(root) end)
    return value
end

local function rooted_launch(config, root)
    local mt = getmetatable(config)
    local native_call = mt and mt.__call
    local wrapped = vim.deepcopy(config)
    return setmetatable(wrapped, {
        __call = function()
            -- Native loading owns JSONC, platform overrides and ${input:...}.
            local resolved = native_call and native_call(config) or config
            local bound, err = bind_workspace(resolved, root)
            if err then return abort(config, err ~= require('dap').ABORT and err or nil) end
            bound.cwd = bound.cwd or root
            bound.aakash_esp_root = root
            return bound
        end,
    })
end

-- Keep the native launch.json provider, but give it the shared project root
-- and retain that origin across native configuration/input selection. Other
-- adapter configurations are not transformed.
M.providers = {
    ['dap.launch.json'] = function()
        local cwd = vim.fn.getcwd()
        local root = require('aakash.project').get()
        local configs, err = launch_configs(cwd)
        if err then
            notify(err)
            return {}
        end
        if (vim.uv.fs_realpath(cwd) or cwd) ~= root then
            local project_configs
            project_configs, err = launch_configs(root)
            if err then
                notify(err)
                return {}
            end
            -- Keep every other adapter on nvim-dap's native cwd policy. Only
            -- probe configurations follow the editor's shared project root.
            configs = vim.tbl_filter(function(config) return config.type ~= adapter_type end, configs)
            for _, config in ipairs(project_configs) do
                if config.type == adapter_type then table.insert(configs, rooted_launch(config, root)) end
            end
        else
            for index, config in ipairs(configs) do
                if config.type == adapter_type then configs[index] = rooted_launch(config, root) end
            end
        end
        return configs
    end,
}

local function configuration_error(config)
    if config.request ~= 'launch' and config.request ~= 'attach' then
        return 'Set request to "launch" or "attach" in the selected probe-rs launch.json configuration.'
    end
    if type(config.chip) ~= 'string' or config.chip == '' or config.chip:find '%s' or config.chip:find '%${' then
        return 'Set an explicit probe-rs chip name in the selected project\'s .vscode/launch.json ("chip"). A Rust target triple does not identify the chip.'
    end
    if type(config.coreConfigs) ~= 'table' or not vim.islist(config.coreConfigs) or type(config.coreConfigs[1]) ~= 'table' then
        return 'The selected probe-rs launch.json configuration needs a coreConfigs array containing at least one core configuration.'
    end
    if type(config.cwd) ~= 'string' or config.cwd == '' or config.cwd:find '%${' then
        return 'Set cwd to ${workspaceFolder} or an explicit directory in the selected probe-rs launch.json configuration.'
    end
    if not absolute(config.cwd) then
        local root = config.aakash_esp_root
        if not absolute(root) then return 'A relative probe-rs cwd needs a project launch.json origin; otherwise specify an absolute cwd.' end
        config.cwd = vim.fs.normalize(vim.fs.joinpath(root, config.cwd))
    end
    local directory = vim.uv.fs_stat(config.cwd)
    if not directory or directory.type ~= 'directory' then return ('The probe-rs working directory does not exist: %s'):format(config.cwd) end
end

local function rust_configuration(config)
    if not config.aakash_rust then return config end
    config = vim.deepcopy(config)
    if not absolute(config.cwd) or config.cwd:find '%${' then
        return abort(config, 'Rustaceanvim did not supply an absolute runnable workspace (cwd); refusing to inspect the focused buffer instead.')
    end
    local project, err = require('aakash.esp32').project(config.cwd)
    if err then return abort(config, err) end
    if not project then
        config.aakash_rust = nil
        return config
    end
    if not absolute(config.program) or config.program:find '%${' then
        return abort(config, 'Rustaceanvim did not supply an absolute compiled firmware ELF path.')
    end
    local embedded
    embedded, err = embedded_artifact(config.program)
    if err then return abort(config, err) end
    if not embedded then
        config.aakash_rust = nil
        return config
    end
    local configs
    configs, err = launch_configs(project.root)
    if err then return abort(config, err) end
    local choices = vim.tbl_filter(function(candidate) return candidate.type == adapter_type end, configs)
    if #choices == 0 then
        return abort(
            config,
            ('Add a probe-rs-debug launch or attach configuration with chip and coreConfigs to %s/.vscode/launch.json. Firmware will not be launched on the host.'):format(
                project.root
            )
        )
    end
    local selected = require('dap.ui').pick_if_many(choices, 'Firmware debugger: ', function(candidate) return candidate.name or adapter_type end)
    if not selected then return abort(config) end
    if type(selected.coreConfigs) ~= 'table' or type(selected.coreConfigs[1]) ~= 'table' then
        return abort(config, "The selected probe-rs launch.json configuration needs coreConfigs[1] for Rustaceanvim's compiled ELF.")
    end
    selected.coreConfigs[1].programBinary = config.program
    -- Rustaceanvim already built this exact runnable. Never run the project's
    -- build task again (nor request input for an ELF path that we replace).
    selected.preLaunchTask = nil
    selected = rooted_launch(selected, project.root)()
    local dap = require 'dap'
    if selected.aakash_abort == dap.ABORT then return selected end
    -- on_config is unordered, and Rustacean's LLDB merges drop metatables.
    -- Expand only our newly selected config, which the native listener may
    -- already have passed. Workspace paths were bound before any UI yielded.
    local expand = dap.listeners.on_config['dap.expand_variable']
    if type(expand) ~= 'function' then
        return abort(selected, 'The installed nvim-dap variable expander is unavailable; update the ESP32 debug integration before launching firmware.')
    end
    selected = expand(selected)
    err = configuration_error(selected)
    if err then return abort(selected, err) end
    -- Overseer's keyed post-task hook is idempotent; install it if its listener
    -- already ran. preLaunchTask is gone, so this cannot rebuild the firmware.
    if selected.postDebugTask and dap.listeners.on_config.overseer then selected = dap.listeners.on_config.overseer(selected) end
    return selected
end

M.adapters = {
    [adapter_type] = function(callback, config)
        local err = configuration_error(config)
        if err then
            notify(err)
            return
        end
        if vim.fn.executable 'probe-rs' ~= 1 then
            notify 'probe-rs is not on PATH. Make the installed probe-rs 0.32+ available before starting Neovim.'
            return
        end
        local esp32 = require 'aakash.esp32'
        local available, reason = esp32.probe_available()
        if not available then
            notify(reason or 'Stop the active probe-rs debugger before starting another probe session.')
            return
        end
        -- Only actual launches claim a probe. Configuration discovery must not
        -- dispose monitors/tasks or open hardware. UART-only tasks can coexist.
        esp32.stop_tasks 'probe'
        config.aakash_esp_root = nil
        callback {
            type = 'executable',
            command = 'probe-rs',
            args = { 'dap-server' }, -- 0.32 uses stdio when --port is omitted.
            options = { cwd = config.cwd },
        }
    end,
}

local function is_probe(session) return session.config.type == adapter_type end
local function console(text) require('dap.repl').append(text, '$', { newline = false }) end
local function event_error(event, body)
    local message = ('Malformed %s event: %s'):format(event, vim.inspect(body))
    console('[probe-rs] ' .. message .. '\n')
    notify(message)
end

-- probe-rs 0.32 debug_adapter/dap/dap_types.rs defines the camelCase bodies;
-- server/debugger.rs dispatches rttWindowOpened. The REPL buffer is ready before
-- acknowledging a channel, so polling never loses output to an unopened sink.
M.listeners = {
    on_config = { aakash_esp32 = rust_configuration },
    after = {
        ['event_probe-rs-rtt-channel-config'] = {
            aakash_esp32 = function(session, body)
                if not is_probe(session) then return end
                if type(body) ~= 'table' or type(body.channelNumber) ~= 'number' or body.channelNumber < 0 or body.channelNumber % 1 ~= 0 then
                    event_error('probe-rs-rtt-channel-config', body)
                    return
                end
                console(('\n[probe-rs RTT %d: %s (%s)]\n'):format(body.channelNumber, tostring(body.channelName), tostring(body.dataFormat)))
                session:request('rttWindowOpened', { channelNumber = body.channelNumber, windowIsOpen = true }, function(err)
                    if err then
                        local message = ('RTT channel %d handshake failed: %s'):format(body.channelNumber, tostring(err))
                        console('[probe-rs] ' .. message .. '\n')
                        notify(message)
                    end
                end)
            end,
        },
        ['event_probe-rs-rtt-data'] = {
            aakash_esp32 = function(session, body)
                if not is_probe(session) then return end
                if type(body) ~= 'table' or type(body.data) ~= 'string' then
                    event_error('probe-rs-rtt-data', body)
                    return
                end
                -- Data is already decoded by probe-rs (including defmt). Keep
                -- partial chunks/newlines intact like the standard DAP output.
                console(body.data)
            end,
        },
        ['event_probe-rs-show-message'] = {
            aakash_esp32 = function(session, body)
                if not is_probe(session) then return end
                if type(body) ~= 'table' or type(body.message) ~= 'string' then
                    event_error('probe-rs-show-message', body)
                    return
                end
                console(body.message)
                local severity = { information = vim.log.levels.INFO, warning = vim.log.levels.WARN, error = vim.log.levels.ERROR }
                vim.notify(vim.trim(body.message), severity[body.severity] or vim.log.levels.INFO, { title = 'probe-rs' })
            end,
        },
        ['event_probe-rs-create-prompt'] = {
            aakash_esp32 = function(session, body)
                if not is_probe(session) then return end
                if type(body) ~= 'table' or body.promptKind ~= 'rtt' or type(body.promptHandle) ~= 'number' then
                    event_error('probe-rs-create-prompt', body)
                    return
                end
                -- Use the adapter's native REPL command for down channels,
                -- rather than creating a terminal or sending unsolicited data.
                console(('\n[probe-rs RTT input %s] Use `rtt write %d <text>` in this REPL.\n'):format(tostring(body.promptName), body.promptHandle))
            end,
        },
    },
}

return M
