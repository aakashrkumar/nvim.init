-- ============================================================
-- RUST
-- Rustaceanvim, Cargo manifest tooling, formatting, runnables via Overseer
-- ============================================================

-- Runnables, tests, and crate test suites become Overseer tasks: they land
-- in the shared task list with cargo's errorformat instead of a throwaway
-- split terminal. The errorformat mirrors Overseer's own cargo template.
---@type rustaceanvim.Executor
local overseer_executor = {
  execute_command = function(command, args, cwd, opts)
    local overseer = require 'overseer'
    overseer
      .new_task({
        cmd = vim.list_extend({ command }, args),
        cwd = cwd,
        env = opts and opts.env,
        components = {
          {
            'on_output_quickfix',
            open_on_exit = 'failure',
            errorformat = [[%Eerror: %\%%(aborting %\|could not compile%\)%\@!%m,]]
              .. [[%Eerror[E%n]: %m,]]
              .. [[%Inote: %m,]]
              .. [[%Wwarning: %\%%(%.%# warning%\)%\@!%m,]]
              .. [[%C %#--> %f:%l:%c,]]
              .. [[%E  left:%m,%C right:%m %f:%l:%c,%Z,]]
              .. [[%.%#panicked at \'%m\'\, %f:%l:%c]],
          },
          { 'open_output', direction = 'dock', on_start = 'always' },
          'default',
        },
      })
      :start()
  end,
}

-- Scope the host runner to this task without adding --target: ordinary Cargo
-- builds keep their cache layout and host/build-script flag handling. This
-- profiles host executables; cross-target/device workflows stay in Cargo.
local function cargo_profile_host(cwd, env)
  for name in pairs(env) do
    if name:match '^CARGO_TARGET_.+_RUNNER$' then error('Profiling supplies the Cargo runner; remove ' .. name .. ' from the profiling environment') end
  end

  -- Resolve after the parameter form: task-local PATH/RUSTUP_TOOLCHAIN/RUSTC
  -- must affect this query as well as Cargo. The member cwd retains rustup's
  -- directory overrides. A compiler override is one executable, not a shell.
  local rustc = env.RUSTC or vim.env.RUSTC or env.CARGO_BUILD_RUSTC or vim.env.CARGO_BUILD_RUSTC or 'rustc'
  local ok, process = pcall(vim.system, { rustc, '-vV' }, { cwd = cwd, env = env, text = true })
  if not ok then error('Cannot inspect rustc for local profiling: ' .. tostring(process)) end
  local result = process:wait(10000)
  if result.code ~= 0 then error('rustc -vV failed for local profiling: ' .. vim.trim(result.stderr or '')) end
  local host = ('\n' .. (result.stdout or '')):match '\nhost: ([%w_-]+)[\r\n]'
  if not host then error 'rustc -vV did not report a host triple for local profiling' end
  return host
end

local function cargo_profile_runner(prefix, cmd, host)
  -- Cargo's array form preserves argv, unlike its whitespace-split string
  -- runner. Escape TOML basic strings, not shell words (including paths with
  -- spaces, quotes, backslashes, and control characters).
  local args = {}
  for i, arg in ipairs(prefix) do
    args[i] = '"' .. arg:gsub('[%z\1-\31\127\\"]', function(char) return string.format('\\u%04x', char:byte()) end) .. '"'
  end
  local wrapped = { cmd[1], '--config', 'target.' .. host .. '.runner=[' .. table.concat(args, ',') .. ']' }
  for i = 2, #cmd do
    wrapped[#wrapped + 1] = cmd[i]
  end
  return wrapped
end

local function cargo_profile_template(package, target, kind, root)
  local name = ('Profile Rust: %s (%s %s)'):format(package.name, kind, target.name)
  local cwd = vim.fs.dirname(package.manifest_path)
  -- cargo-instruments supports these Cargo target kinds, but not --test.
  local instruments_available = vim.uv.os_uname().sysname == 'Darwin' and kind ~= 'test'
  return {
    name = name,
    desc = 'Profile a host executable using Cargo’s normal build target, profile, and cache.',
    tags = { 'PROFILE' },
    params = function()
      local params = require('aakash.performance').params()
      -- Define [profile.profiling] in the workspace Cargo.toml with
      -- inherits = "release", debug = true, strip = "none", or choose another
      -- existing profile here. A missing profile fails in Cargo's own output.
      -- Do not silently change project RUSTFLAGS or rewrite its profiles.
      -- If Linux perf callgraphs from LLD-built code are truncated, an opt-in
      -- workaround is -C link-arg=-Wl,--no-rosegment. Other linkers may reject it.
      -- Task RUSTFLAGS overrides Cargo's configured rustflags and can trigger
      -- rebuilds; preserve existing flags when trying the workaround.
      params.profile = { type = 'string', name = 'Cargo profile', default = 'profiling', desc = 'Existing Cargo profile', order = 5 }
      params.features = {
        type = 'list',
        name = 'Features',
        order = 6,
        subtype = { type = 'string' },
        delimiter = ',',
        default = target['required-features'] or {},
        desc = 'Cargo feature names, comma separated (defaults to target required-features)',
      }
      params.all_features = { type = 'boolean', name = 'All features', default = false, desc = 'Enable all Cargo features', order = 7 }
      params.no_default_features = { type = 'boolean', name = 'No default features', default = false, desc = 'Disable default Cargo features', order = 8 }
      if instruments_available then
        table.insert(params.backend.choices, 'instruments')
        params.instruments_template = {
          type = 'string',
          name = 'Instruments template',
          default = 'Time Profiler',
          order = 9,
          desc = 'Instruments only; use cargo instruments --list-templates for built-in and custom names',
        }
        params.instruments_time_limit = {
          type = 'integer',
          name = 'Instruments limit (ms; 0 = default)',
          default = 0,
          order = 10,
          desc = 'Instruments only; 0 uses its default; a positive limit terminates the target after this many milliseconds',
          validate = function(value) return value >= 0, 'The recording limit must be non-negative' end,
        }
      end
      return params
    end,
    builder = function(params)
      local performance = require 'aakash.performance'
      local env = performance.environment(params.env)
      local instruments = params.backend == 'instruments'
      if instruments and not instruments_available then error('Cargo Instruments requires macOS and a binary, example, or benchmark target', 0) end
      local host = not instruments and cargo_profile_host(cwd, env) or nil
      -- Cargo also interprets globs without a shell. Never let one selection
      -- expand to multiple test/benchmark executables sharing an output file.
      if target.name:find '[*?%[%]]' then error('Cannot profile a Cargo target whose name contains glob characters: ' .. target.name) end
      local command = instruments and 'instruments' or (kind == 'bin' or kind == 'example') and 'run' or kind
      local cmd = {
        'cargo',
        command,
        '--manifest-path',
        package.manifest_path,
        '--package',
        package.name,
        '--' .. kind,
        target.name,
        '--profile=' .. (params.profile or 'profiling'),
      }
      if instruments then
        vim.list_extend(cmd, { '--template', params.instruments_template })
        if params.instruments_time_limit > 0 then vim.list_extend(cmd, { '--time-limit', tostring(params.instruments_time_limit) }) end
        -- cargo-instruments accepts one --features value, unlike cargo run.
        if #(params.features or {}) > 0 then vim.list_extend(cmd, { '--features', table.concat(params.features, ',') }) end
      else
        for _, feature in ipairs(params.features or {}) do
          cmd[#cmd + 1] = '--features=' .. feature
        end
      end
      if params.all_features then cmd[#cmd + 1] = '--all-features' end
      if params.no_default_features then cmd[#cmd + 1] = '--no-default-features' end
      cmd[#cmd + 1] = '--'
      vim.list_extend(cmd, performance.arguments(params.args))
      return performance.capture(
        {
          name = name,
          cmd = cmd,
          cwd = cwd,
          env = env,
          metadata = { profile = { root = root } },
        },
        params.backend,
        function(prefix, argv)
          if instruments then
            for i = 3, #argv do
              prefix[#prefix + 1] = argv[i]
            end
            return prefix
          end
          return cargo_profile_runner(prefix, argv, host)
        end
      )
    end,
  }
end

---@type overseer.TemplateFileProvider
local cargo_profile_provider = {
  name = 'Rust profiling',
  generator = function(opts, cb)
    local manifest = vim.fs.find('Cargo.toml', { upward = true, type = 'file', path = opts.dir })[1]
    if not manifest then return 'Not inside a Cargo project' end
    if vim.fn.executable 'cargo' == 0 then return 'Rust profiling requires cargo on PATH' end

    -- No attached server or hand-parsed manifests: Cargo discovers workspace
    -- members and executable targets asynchronously without network/lock edits.
    vim.system(
      { 'cargo', 'metadata', '--no-deps', '--offline', '--locked', '--format-version', '1' },
      { cwd = vim.fs.dirname(manifest), text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then return cb('Cargo profiling discovery failed: ' .. vim.trim(result.stderr or '')) end
        local ok, metadata = pcall(vim.json.decode, result.stdout)
        if not ok or type(metadata) ~= 'table' or type(metadata.packages) ~= 'table' or type(metadata.workspace_members) ~= 'table' then
          return cb 'Cargo profiling discovery returned invalid metadata'
        end
        local members = {}
        for _, id in ipairs(metadata.workspace_members) do
          members[id] = true
        end
        local templates = {}
        for _, package in ipairs(metadata.packages) do
          if members[package.id] then
            for _, target in ipairs(package.targets) do
              local kind = target.kind[1]
              if (kind == 'bin' or kind == 'example' or kind == 'bench' or kind == 'test') and vim.tbl_contains(target.crate_types, 'bin') then
                templates[#templates + 1] = cargo_profile_template(package, target, kind, opts.dir)
              end
            end
          end
        end
        cb(templates)
      end)
    )
  end,
}

return {
  -- [[ Rust ]]
  {
    'mrcjkb/rustaceanvim',
    -- To avoid being surprised by breaking changes, Rustaceanvim recommends a
    -- tagged major-version range. The plugin implements proper Neovim-native
    -- lazy loading itself, so its official lazy.nvim example sets `lazy = false`.
    version = '^9',
    lazy = false,
    -- This must be defined before rustaceanvim initializes.
    init = function()
      vim.g.rustaceanvim = {
        tools = {
          executor = overseer_executor,
          test_executor = overseer_executor,
          crate_test_executor = overseer_executor,
          code_actions = {
            ui_select_fallback = true,
          },
          float_win_config = {
            border = 'rounded',
            auto_focus = true,
          },
        },

        server = {
          on_attach = function(client, bufnr)
            local map = function(lhs, rhs, desc)
              vim.keymap.set('n', lhs, rhs, {
                buffer = bufnr,
                silent = true,
                desc = 'Rust: ' .. desc,
              })
            end

            if client:supports_method('textDocument/inlayHint', bufnr) then vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end

            if client:supports_method('textDocument/codeLens', bufnr) then
              map('<leader>tl', function()
                local is_enabled = vim.lsp.codelens.is_enabled { bufnr = bufnr }
                vim.lsp.codelens.enable(not is_enabled, { bufnr = bufnr })
              end, 'Toggle CodeLens')
            end

            -- More powerful than ordinary LSP hover: the window is actionable.
            map('K', function() vim.cmd.RustLsp { 'hover', 'actions' } end, 'Hover actions')

            -- Shows Rustaceanvim's grouped code-action UI.
            map('grA', function() vim.cmd.RustLsp 'codeAction' end, 'Grouped code actions')

            map('<leader>rr', function() vim.cmd.RustLsp 'runnables' end, 'Runnables')

            map('<leader>rD', function() vim.cmd.RustLsp 'debuggables' end, 'Debuggables')

            map('<leader>re', function() vim.cmd.RustLsp { 'explainError', 'current' } end, 'Explain error')

            map('<leader>rE', function() vim.cmd.RustLsp { 'renderDiagnostic', 'current' } end, 'Render diagnostic')

            map('<leader>rm', function() vim.cmd.RustLsp 'expandMacro' end, 'Expand macro')

            map('<leader>rc', function() vim.cmd.RustLsp 'openCargo' end, 'Open Cargo.toml')

            map('<leader>rd', function() vim.cmd.RustLsp 'openDocs' end, 'Open documentation')
          end,

          default_settings = {
            ['rust-analyzer'] = {
              check = {
                command = 'clippy',
                extraArgs = { '--no-deps' },
              },

              completion = {
                -- Show complete function and method signatures in completion documentation.
                fullFunctionSignatures = {
                  enable = true,
                },
                -- Keep obsolete APIs out of completion results.
                hideDeprecated = true,
              },

              files = {
                exclude = {
                  '.direnv',
                  '.git',
                  '.jj',
                  '.venv',
                  'node_modules',
                  'target',
                  'venv',
                },
              },

              -- Enable only in projects where you normally build all features:
              -- cargo = {
              --   features = 'all',
              -- },
            },
          },
        },
      }
    end,
  },

  {
    'stevearc/overseer.nvim',
    opts = function(_, opts)
      opts.templates = opts.templates or {}
      table.insert(opts.templates, cargo_profile_provider)
    end,
  },

  -- The general LSP list intentionally does not enable this server:
  -- rust_analyzer = {},
  -- Rustaceanvim's documentation warns that configuring rust-analyzer through
  -- both mechanisms can create conflicting clients.

  -- Crates
  {
    'Saecki/crates.nvim',
    -- This is the plugin's documented lazy-loading pattern: the first read of a
    -- Cargo manifest loads Crates and configures its completion/LSP helpers.
    event = 'BufRead Cargo.toml',
    opts = {
      completion = {
        crates = {
          enabled = true,
        },
      },

      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- Filetype-keyed Conform options merge regardless of module order.
  -- Shared installation/key lists below need append functions instead.
  {
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        rust = { 'rustfmt' },
      },
      format_on_save_by_ft = {
        rust = { timeout_ms = 1000 },
      },
    },
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, 'codelldb') then table.insert(opts.ensure_installed, 'codelldb') end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>r', group = '[R]ust' })
    end,
  },
}
