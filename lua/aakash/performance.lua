-- Local profiling glue. Overseer owns execution; the profilers own their data
-- and viewers. Language modules only supply a command or adapt its runner.
local M = {}
local project = require 'aakash.project'
local loading_file

local function normalize(path) return vim.fs.normalize(vim.uv.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')) end

local function directory(root) return vim.fs.joinpath(vim.fn.stdpath 'cache', 'profiling', vim.fn.sha256(normalize(root)):sub(1, 16)) end

function M.artifact_path(root, backend)
  local suffix = backend == 'samply' and '.json.gz' or backend == 'instruments' and '.trace' or '.data'
  return vim.fs.joinpath(directory(root), ('%s-%d-%.0f%s'):format(backend, vim.fn.getpid(), vim.uv.hrtime(), suffix))
end

-- Instruments writes a document bundle, not a single perf/Samply data file.
-- Require its template and a recorded run; an empty .trace directory is not a capture.
-- cargo-instruments can exit zero after xctrace errors; exit status alone is not enough.
function M.artifact_stat(file, backend)
  local stat = vim.uv.fs_stat(file)
  if not stat then return end
  if backend ~= 'instruments' then return stat.type == 'file' and stat.size > 0 and stat or nil end
  if stat.type ~= 'directory' then return end
  local template = vim.uv.fs_stat(vim.fs.joinpath(file, 'form.template'))
  if not template or template.type ~= 'file' or template.size == 0 then return end
  for name, kind in vim.fs.dir(file) do
    if kind == 'directory' and name:match '^Trace%d+%.run$' then return stat end
  end
end

-- JSON keeps spaces, quotes, commas, and empty arguments literal. Overseer's
-- native list field splits on commas and is unsuitable for arbitrary argv.
function M.arguments(text)
  local args = (not text or text == '') and {} or vim.json.decode(text)
  if type(args) ~= 'table' or not vim.islist(args) then error('Arguments must be a JSON array of strings', 0) end
  for _, arg in ipairs(args) do
    if type(arg) ~= 'string' or arg:find('\0', 1, true) then error('Each argument must be a string without NUL bytes', 0) end
  end
  return args
end

function M.environment(text, base)
  local values = (not text or text == '') and {} or vim.json.decode(text)
  if type(values) ~= 'table' then error('Environment must be a JSON object of string values', 0) end
  local env = vim.tbl_extend('force', {}, base or {})
  for name, value in pairs(values) do
    if type(name) ~= 'string' or name == '' or name:find '[=%z]' or type(value) ~= 'string' or value:find('\0', 1, true) then
      error('Environment must contain valid variable names and string values', 0)
    end
    env[name] = value
  end
  return env
end

function M.params()
  local params = {
    -- The Snacks menu edits individual entries and encodes them for Overseer.
    -- Leave args required so direct :OverseerRun still opens its native form.
    args = {
      type = 'string',
      name = 'Arguments',
      desc = 'Program arguments as JSON, e.g. ["--input", "a file.txt"]; [] means none',
      order = 20,
      validate = function(value) return pcall(M.arguments, value) end,
    },
    env = {
      type = 'string',
      name = 'Environment',
      desc = 'Environment overrides as JSON, e.g. {"RUST_LOG":"info"}',
      default = '{}',
      order = 30,
      validate = function(value) return pcall(M.environment, value) end,
    },
  }
  local linux = vim.uv.os_uname().sysname == 'Linux'
  params.backend = { type = 'enum', name = 'Profiler', choices = linux and { 'samply', 'perf' } or { 'samply' }, default = 'samply', order = 1 }
  return params
end

local function viewer(file, root)
  return {
    name = 'Samply viewer: ' .. vim.fs.basename(root),
    cmd = { 'samply', 'load', file },
    cwd = root,
    -- Do not inherit workload-specific environment overrides from run_after.
    env = {},
    metadata = { profile_viewer = root, profile_file = file },
    components = {
      { 'unique', compare = function(a, b) return a.metadata.profile_viewer == b.metadata.profile_viewer end },
      'default',
    },
  }
end

---@param task overseer.TaskDefinition
---@param backend? string
---@param wrap? fun(prefix: string[], command: string[]): string[]
---@return overseer.TaskDefinition
function M.capture(task, backend, wrap)
  backend = backend or 'samply'
  if backend ~= 'samply' and backend ~= 'perf' and backend ~= 'instruments' then error('Unknown profiler: ' .. backend, 0) end
  local system = vim.uv.os_uname().sysname
  if backend == 'perf' and system ~= 'Linux' then error('perf/PerfAnno capture requires Linux', 0) end
  if backend == 'instruments' and system ~= 'Darwin' then error('Cargo Instruments capture requires macOS', 0) end
  local executable = backend == 'instruments' and 'cargo-instruments' or backend
  if vim.fn.executable(executable) ~= 1 then error(('Profiling requires %s on PATH; see :checkhealth aakash'):format(executable), 0) end
  task.metadata = task.metadata or {}
  local root = normalize(task.metadata.profile and task.metadata.profile.root or task.cwd or project.get())
  local file = M.artifact_path(root, backend)
  local prefix
  if backend == 'instruments' then
    -- Cargo owns building and symbols; the component opens only validated traces.
    prefix = { 'cargo', 'instruments', '--no-open', '--output', file }
  elseif backend == 'samply' then
    prefix = { 'samply', 'record', '--save-only', '-o', file, '--' }
  else
    prefix = { 'perf', 'record', '-e', 'cycles:u', '--call-graph', 'dwarf', '-o', file, '--' }
  end
  task.cmd = wrap and wrap(prefix, task.cmd) or vim.list_extend(prefix, task.cmd)
  task.name = (task.name or 'Profile') .. ' [' .. backend .. ']'
  task.cwd = task.cwd or root
  task.metadata.profile = { root = root, file = file, backend = backend }
  task.components = task.components or {}
  vim.list_extend(task.components, {
    'aakash.profile',
    {
      'unique',
      soft = true,
      compare = function(a, b) return b.metadata.profile.ready and a.metadata.profile ~= nil and a.metadata.profile.root == b.metadata.profile.root end,
    },
    -- The default five-minute disposal would kill a linked viewer and remove
    -- the task needed by ProfileRepeat. Other tasks keep their normal policy.
    { 'on_complete_dispose', statuses = {} },
  })
  if backend == 'samply' then table.insert(task.components, { 'run_after', tasks = { viewer(file, root) } }) end
  -- aakash.profile validates the artifact before setting status. Include the
  -- other defaults explicitly, without a second on_exit_set_status component.
  table.insert(task.components, 'on_complete_notify')
  return task
end

-- Artifacts stay in native format, not a parallel history database.
-- Samply/perf repeat in place; Instruments repeats get fresh document bundles.
local function latest(backend)
  local root = normalize(project.get())
  local dir = directory(root)
  if not vim.uv.fs_stat(dir) then return nil end
  local result, timestamp
  for name in vim.fs.dir(dir) do
    local tool = name:match '^samply%-.+%.json%.gz$' and 'samply'
      or name:match '^perf%-.+%.data$' and 'perf'
      or name:match '^instruments%-.+%.trace$' and 'instruments'
    if tool and (not backend or backend == tool) then
      local file = vim.fs.joinpath(dir, name)
      local stat = M.artifact_stat(file, tool)
      if stat then
        local time = stat.mtime.sec + stat.mtime.nsec / 1e9
        if not timestamp or time > timestamp then
          result, timestamp = { file = file, backend = tool, root = root }, time
        end
      end
    end
  end
  return result
end

function M.perf_file()
  if loading_file then return loading_file end
  local result = latest 'perf'
  if result then return result.file end
  vim.notify('No perf capture for this project', vim.log.levels.WARN)
end

function M.load_perf(mode, file)
  if vim.uv.os_uname().sysname ~= 'Linux' then
    vim.notify('PerfAnno loading requires local Linux perf', vim.log.levels.WARN)
    return
  end
  file = file or M.perf_file()
  if not file then return end
  loading_file = file
  local ok, err = pcall(function()
    require('lazy').load { plugins = { 'perfanno.nvim' } }
    vim.notify 'Loading local perf capture…'
    vim.cmd.redraw()
    local perfanno = require 'perfanno'
    if mode == 'callgraph' then
      perfanno.load_perf_callgraph()
    else
      perfanno.load_perf_flat()
    end
  end)
  loading_file = nil
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

function M.open()
  local result = latest()
  if not result then
    vim.notify('No saved profile for this project', vim.log.levels.WARN)
  elseif result.backend == 'perf' then
    M.load_perf('flat', result.file)
  elseif result.backend == 'instruments' then
    if vim.uv.os_uname().sysname ~= 'Darwin' then return vim.notify('Opening Instruments traces requires macOS', vim.log.levels.WARN) end
    local _, err = vim.ui.open(result.file)
    if err then vim.notify(err, vim.log.levels.ERROR) end
  else
    local overseer = require 'overseer'
    -- run_after owns an ephemeral viewer; unique does not search those tasks.
    -- Reuse it so reopening preserves parent/child cleanup and one server.
    local existing = overseer.list_tasks({
      include_ephemeral = true,
      filter = function(task) return task.metadata.profile_viewer == result.root and task.metadata.profile_file == result.file end,
    })[1]
    if existing then
      existing:restart(true)
    else
      overseer.new_task(viewer(result.file, result.root)):start()
    end
  end
end

local function last_capture()
  local root = normalize(project.get())
  local tasks = require('overseer').list_tasks {
    filter = function(task) return task.time_start ~= nil and task.metadata.profile ~= nil and task.metadata.profile.root == root end,
    sort = function(a, b)
      if a.time_start == b.time_start then return a.id > b.id end
      return a.time_start > b.time_start
    end,
  }
  return tasks[1]
end

function M.repeat_last()
  local task = last_capture()
  if task then
    require('overseer').run_action(task, 'restart')
  else
    vim.notify('No profiling task to repeat; run :Profile first', vim.log.levels.WARN)
  end
end

function M.toggle_output()
  -- Close before resolving the project: an output buffer has no source path.
  local win = vim.api.nvim_get_current_win()
  if vim.w[win].aakash_profile_output and vim.api.nvim_win_get_config(win).relative ~= '' then
    vim.api.nvim_win_close(win, true)
    return
  end
  local task = last_capture()
  if not task or not task:get_bufnr() then
    vim.notify('No profiling output for this project; run :Profile first', vim.log.levels.WARN)
    return
  end
  -- Overseer owns the terminal buffer and dismisses its float on WinLeave.
  task:open_output 'float'
  vim.w.aakash_profile_output = true
  -- A space-prefixed terminal mapping must not delay typing in other shells.
  vim.keymap.set('t', '<leader>Pf', M.toggle_output, { buffer = 0, desc = 'Toggle profiling output' })
end

function M.run()
  local registry = require 'overseer.template'
  local search = { dir = project.get(), filetype = vim.bo.filetype, tags = { 'PROFILE' } }
  -- Use the registered providers and their schemas, not a second catalogue.
  -- No task is built until Run, so cancelling cannot start a profiler.
  registry.list(search, function(found)
    local templates = vim.tbl_filter(function(template) return not template.hide end, found)
    table.sort(templates, function(a, b) return a.name < b.name end)
    if #templates == 0 then return vim.notify('No profiling targets in ' .. search.dir, vim.log.levels.WARN) end
    local drafts = {}
    local choose_target
    choose_target = function()
      vim.ui.select(
        templates,
        { prompt = 'Profile target', kind = 'overseer_template', format_item = function(template) return template.name end },
        function(template)
          if not template then return end
          drafts[template.name] = drafts[template.name] or {}
          local ok, err = pcall(require('aakash.profile_config').open, template, drafts[template.name], function(params)
            registry.build_task(template, { params = params, search = search, disallow_prompt = true }, function(reason, task)
              if reason then error(reason, 0) end
              if task then task:start() end
            end)
          end, choose_target)
          if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
        end
      )
    end
    choose_target()
  end)
end

---@type overseer.TemplateFileProvider
M.program = {
  name = 'Profile program',
  generator = function(opts)
    local params = M.params()
    params.program = { type = 'string', name = 'Executable', desc = 'Executable path or command on PATH (not a shell command)', order = 2 }
    params.cwd = { type = 'string', name = 'Working directory', default = opts.dir, desc = 'Program working directory', order = 3 }
    return {
      {
        name = 'Profile program',
        desc = 'Profile an existing local executable; build it first if needed',
        tags = { 'PROFILE' },
        params = params,
        builder = function(values)
          local cwd = normalize(values.cwd)
          local stat = vim.uv.fs_stat(cwd)
          if not stat or stat.type ~= 'directory' then error('Working directory does not exist: ' .. cwd, 0) end
          local program = values.program:gsub('^~/', vim.env.HOME .. '/')
          if program:find('/', 1, true) and program:sub(1, 1) ~= '/' then program = vim.fs.joinpath(cwd, program) end
          return M.capture({
            name = 'Profile program: ' .. vim.fs.basename(program),
            cmd = vim.list_extend({ program }, M.arguments(values.args)),
            cwd = cwd,
            env = M.environment(values.env),
            metadata = { profile = { root = opts.dir } },
          }, values.backend)
        end,
      },
    }
  end,
}

return M
