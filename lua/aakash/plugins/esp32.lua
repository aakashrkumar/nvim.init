-- ============================================================
-- ESP32
-- ESP-IDF and PlatformIO tasks, ESP-IDF debugging over OpenOCD
-- ============================================================

-- [[ ESP-IDF environment ]]
-- idf.py, the cross toolchains, and OpenOCD only exist inside an activated
-- ESP-IDF environment. Every task and the debug adapter run inside one.
-- The install is chosen in this order:
--   1. Neovim was started from an activated shell: use it as is.
--   2. $IDF_PATH names an install: activate its `export.sh`.
--   3. The install selected in ESP-IDF Installation Manager (`eim_idf.json`).

---@class aakash.IdfEnvironment
---@field path string IDF_PATH
---@field activate? string script to source before running a command

---@return aakash.IdfEnvironment|nil
local function idf_environment()
  if vim.env.IDF_PATH and vim.env.IDF_PYTHON_ENV_PATH then return { path = vim.env.IDF_PATH } end
  if vim.env.IDF_PATH then return { path = vim.env.IDF_PATH, activate = vim.fs.joinpath(vim.env.IDF_PATH, 'export.sh') } end

  local registries = { '~/.espressif/tools', '~/.espressif' }
  if vim.env.IDF_TOOLS_PATH then table.insert(registries, 1, vim.env.IDF_TOOLS_PATH) end
  for _, dir in ipairs(registries) do
    local file = io.open(vim.fs.normalize(vim.fs.joinpath(dir, 'eim_idf.json')))
    if file then
      local ok, registry = pcall(vim.json.decode, file:read '*a')
      file:close()
      for _, install in ipairs(ok and registry.idfInstalled or {}) do
        if install.id == registry.idfSelectedId then return { path = install.path, activate = install.activationScript } end
      end
    end
  end
end

-- Argument vector that runs `args` inside `env`. The activation scripts
-- refuse to run unless sourced and decide that from `$0`, hence the `bash`
-- placeholder argument. Their chatter is dropped; the exit status is kept.
---@param env aakash.IdfEnvironment
---@param args string[]
---@return string[]
local function idf_command(env, args)
  if not env.activate then return args end
  return vim.list_extend({
    'bash',
    '-c',
    [[. "$1" >/dev/null 2>&1 || { echo "Could not activate ESP-IDF with $1" >&2; exit 1; }; shift; exec "$@"]],
    'bash',
    env.activate,
  }, args)
end

-- Activation defines `idf.py` as a shell function, so call the script itself.
---@param env aakash.IdfEnvironment
local function idf_py(env) return vim.fs.joinpath(env.path, 'tools', 'idf.py') end

-- Absolute path of `tool` as the activated environment resolves it.
---@param env aakash.IdfEnvironment
---@param tool string
---@return string|nil
local function idf_which(env, tool)
  local result = vim.system(idf_command(env, { 'sh', '-c', 'command -v "$1"', 'sh', tool }), { text = true }):wait()
  local path = vim.trim(result.stdout or '')
  return result.code == 0 and path ~= '' and path or nil
end

-- An ESP-IDF project root holds `sdkconfig` (after the first configure) or
-- the top-level CMakeLists.txt that includes IDF's project.cmake.
local function is_idf_root(name, path)
  if name == 'sdkconfig' or name == 'sdkconfig.defaults' then return true end
  if name ~= 'CMakeLists.txt' then return false end
  -- `vim.fs.find` passes the directory being searched rather than the entry.
  local file = io.open(vim.fs.basename(path) == name and path or vim.fs.joinpath(path, name))
  if not file then return false end
  local content = file:read '*a'
  file:close()
  return content:find('tools/cmake/project.cmake', 1, true) ~= nil
end

-- Written by `idf.py build`: ELF, toolchain prefix, generated gdbinit files.
local function project_description(root)
  local file = io.open(vim.fs.joinpath(root, 'build', 'project_description.json'))
  if not file then return nil end
  local ok, description = pcall(vim.json.decode, file:read '*a')
  file:close()
  return ok and description or nil
end

-- clangd cannot parse the GCC-only flags in ESP-IDF's compile commands and
-- reports each one as an error on every file. Espressif-IDE's answer is a
-- project `.clangd` that drops them. Include-what-you-use is off there too:
-- `freertos/FreeRTOS.h` must be included before `freertos/task.h` yet is
-- never used directly. Written on request by the task below, never on its
-- own: an ESP-IDF root may be a checkout that is not this project's.
local clangd_config = {
  '# clangd rejects the GCC-only flags in ESP-IDF compile commands.',
  'CompileFlags:',
  '  CompilationDatabase: build',
  '  Remove: [-m*, -f*]',
  'Diagnostics:',
  '  UnusedIncludes: None',
}

local function has_clangd_config(root) return vim.uv.fs_stat(vim.fs.joinpath(root, '.clangd')) ~= nil end

---@param root string
---@return overseer.TemplateDefinition
local function clangd_config_template(root)
  return {
    name = 'clangd: write .clangd for ESP-IDF',
    desc = 'Drop GCC-only compile flags and unused-include checks',
    builder = function()
      return {
        cmd = vim.list_extend({ 'sh', '-c', [[printf '%s\n' "$@" > .clangd && echo "wrote $PWD/.clangd"]], 'sh' }, clangd_config),
        cwd = root,
      }
    end,
  }
end

-- [[ Task templates ]]
-- See `:help overseer-components` for the component parameters.
local quickfix_on_failure = { 'on_output_quickfix', open_on_exit = 'failure' }
local focused_terminal = { 'open_output', direction = 'float', focus = true, on_start = 'always' }
-- These templates do not resolve IDF/PIO's selected port, so all serial
-- tasks share one conservative resource across providers and projects,
-- not a per-device lock. OpenOCD owns a separate resource; builds own none.
local function same_resource(a, b) return a.metadata.esp_resource ~= nil and a.metadata.esp_resource == b.metadata.esp_resource end

---@class aakash.TaskSpec
---@field name? string task name when `args` is a function
---@field args string[]|fun(params: table): string[]
---@field tags? string[]
---@field params? overseer.Params
---@field components? overseer.Serialized[]
---@field resource? string exclusive serial port or GDB server resource

---@type aakash.TaskSpec[]
local idf_tasks = {
  { args = { 'build' }, tags = { 'BUILD' }, components = { quickfix_on_failure } },
  { args = { 'flash' }, resource = 'serial', components = { quickfix_on_failure } },
  { args = { 'flash', 'monitor' }, resource = 'serial', tags = { 'RUN' }, components = { focused_terminal } },
  { args = { 'monitor' }, resource = 'serial', components = { focused_terminal } },
  { args = { 'menuconfig' }, components = { focused_terminal } },
  { args = { 'size' } },
  { args = { 'erase-flash' }, resource = 'serial' },
  { args = { 'fullclean' }, tags = { 'CLEAN' } },
  {
    name = 'set-target',
    args = function(params) return { 'set-target', params.target } end,
    params = {
      target = { type = 'string', desc = 'Chip, e.g. esp32, esp32s3, esp32c6' },
    },
  },
  -- GDB server for the debug configuration below.
  { args = { 'openocd' }, resource = 'openocd:localhost:3333' },
}

---@type aakash.TaskSpec[]
local pio_tasks = {
  { args = { 'run' }, tags = { 'BUILD' }, components = { quickfix_on_failure } },
  { args = { 'run', '--target', 'upload' }, resource = 'serial', components = { quickfix_on_failure } },
  { args = { 'run', '--target', 'upload', '--target', 'monitor' }, resource = 'serial', tags = { 'RUN' }, components = { focused_terminal } },
  { args = { 'device', 'monitor' }, resource = 'serial', components = { focused_terminal } },
  { args = { 'test' }, tags = { 'TEST' } },
  -- compile_commands.json for clangd.
  { args = { 'run', '--target', 'compiledb' } },
  { args = { 'run', '--target', 'clean' }, tags = { 'CLEAN' } },
}

---@param label string shown before the arguments in the task name
---@param cwd string
---@param spec aakash.TaskSpec
---@param command fun(args: string[]): string[] full argument vector for `args`
---@return overseer.TemplateDefinition
local function template(label, cwd, spec, command)
  return {
    name = label .. ' ' .. (spec.name or table.concat(spec.args, ' ')),
    tags = spec.tags,
    params = spec.params,
    builder = function(params)
      local args = type(spec.args) == 'function' and spec.args(params) or spec.args
      local components = vim.deepcopy(spec.components or {})
      if spec.resource then table.insert(components, { 'unique', compare = same_resource }) end
      table.insert(components, 'default')
      return {
        cmd = command(args),
        cwd = cwd,
        metadata = spec.resource and { esp_resource = spec.resource },
        components = components,
      }
    end,
  }
end

---@type overseer.TemplateFileProvider
local idf_provider = {
  name = 'idf.py',
  generator = function(opts)
    local root = vim.fs.root(opts.dir, is_idf_root)
    if not root then return 'Not inside an ESP-IDF project' end
    local env = idf_environment()
    if not env then return 'No ESP-IDF installation found: set $IDF_PATH or install one with eim' end

    local templates = {}
    for _, spec in ipairs(idf_tasks) do
      templates[#templates + 1] = template('idf.py', root, spec, function(args) return idf_command(env, vim.list_extend({ idf_py(env) }, args)) end)
    end
    if not has_clangd_config(root) then templates[#templates + 1] = clangd_config_template(root) end
    return templates
  end,
}

---@type overseer.TemplateFileProvider
local pio_provider = {
  name = 'pio',
  generator = function(opts)
    local root = vim.fs.root(opts.dir, 'platformio.ini')
    if not root then return 'Not inside a PlatformIO project' end
    local pio = vim.fn.exepath 'pio'
    if pio == '' then pio = vim.fs.normalize(vim.fs.joinpath(vim.env.PLATFORMIO_CORE_DIR or '~/.platformio', 'penv', 'bin', 'pio')) end
    if not vim.uv.fs_stat(pio) then return 'PlatformIO Core (pio) is not installed' end

    local templates = {}
    for _, spec in ipairs(pio_tasks) do
      templates[#templates + 1] = template('pio', root, spec, function(args) return vim.list_extend({ pio }, args) end)
    end
    return templates
  end,
}

-- [[ Debugging ]]
-- GDB attaches to OpenOCD (the `idf.py openocd` task) through cpptools'
-- adapter, running the toolchain GDB from the activated environment.
local function esp_idf_configuration(root)
  local function from_build(pick)
    return function()
      local description = project_description(root)
      if not description then
        vim.notify(('ESP-IDF: no build in %s; run idf.py build first'):format(root), vim.log.levels.ERROR)
        return require('dap').ABORT
      end
      return pick(description)
    end
  end

  return {
    name = 'ESP-IDF: attach to OpenOCD (localhost:3333)',
    type = 'esp_idf',
    request = 'launch',
    cwd = root,
    MIMode = 'gdb',
    miDebuggerServerAddress = 'localhost:3333',
    miDebuggerPath = from_build(function(description)
      local gdb = description.monitor_toolprefix .. 'gdb'
      local env = idf_environment()
      local path = env and idf_which(env, gdb)
      if not path then
        vim.notify(('ESP-IDF: %s not found in the ESP-IDF environment'):format(gdb), vim.log.levels.ERROR)
        return require('dap').ABORT
      end
      return path
    end),
    program = from_build(function(description) return vim.fs.joinpath(description.build_dir, description.app_elf) end),
    -- Symbols, path prefix map, and FreeRTOS thread support generated by
    -- the build; `idf.py gdb` sources the same files. The `connect` file's
    -- timeout and reset commands appear below. cpptools handles connecting;
    -- leave `continue` to the debugger rather than sourcing it here.
    setupCommands = from_build(function(description)
      local commands = {}
      for _, key in ipairs(vim.tbl_keys(description.gdbinit_files or {})) do
        if key ~= '04_connect' then commands[#commands + 1] = key end
      end
      table.sort(commands)
      for index, key in ipairs(commands) do
        commands[index] = {
          text = 'source ' .. description.gdbinit_files[key],
          -- `idf.py gdb` skips the Python extensions when GDB lacks Python.
          ignoreFailures = key:find('py_extensions', 1, true) ~= nil,
        }
      end
      table.insert(commands, 1, { text = 'set remotetimeout 10' })
      return commands
    end),
    postRemoteConnectCommands = {
      { text = 'monitor reset halt' },
      { text = 'maintenance flush register-cache' },
      { text = 'thbreak app_main' },
    },
  }
end

return {
  {
    'stevearc/overseer.nvim',
    opts = function(_, opts)
      opts.templates = opts.templates or {}
      vim.list_extend(opts.templates, { idf_provider, pio_provider })
    end,
  },

  {
    'mfussenegger/nvim-dap',
    opts = {
      adapters = {
        esp_idf = function(callback)
          local env = idf_environment()
          if not env then
            vim.notify('ESP-IDF: no installation found; set $IDF_PATH or install one with eim', vim.log.levels.ERROR)
            return
          end
          -- The adapter inherits the activated PATH; `miDebuggerPath` is
          -- resolved through the same environment.
          local command = idf_command(env, { 'OpenDebugAD7' })
          callback {
            id = 'cppdbg',
            type = 'executable',
            command = table.remove(command, 1),
            args = command,
          }
        end,
      },
      providers = {
        esp_idf = function(bufnr)
          local root = vim.fs.root(bufnr, is_idf_root)
          return root and { esp_idf_configuration(root) } or {}
        end,
      },
    },
  },

  {
    'mason-org/mason-lspconfig.nvim',
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('aakash-esp-idf-clangd', { clear = true }),
        pattern = { 'c', 'cpp' },
        desc = 'Point at the .clangd task once per ESP-IDF project without one',
        callback = function(event)
          local root = vim.fs.root(event.buf, is_idf_root)
          if root and not has_clangd_config(root) then
            vim.notify_once(
              ('ESP-IDF: %s has no .clangd; clangd will reject GCC-only flags. Run the task "clangd: write .clangd for ESP-IDF".'):format(root),
              vim.log.levels.WARN
            )
          end
        end,
      })
    end,
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'cpptools') then table.insert(opts.ensure_installed, 'cpptools') end
    end,
  },
}
