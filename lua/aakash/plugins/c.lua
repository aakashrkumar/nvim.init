-- ============================================================
-- C / C++
-- clangd, CMake workflow, formatting, and native debugging
-- ============================================================

local project = require 'aakash.project'

-- idf_tools.py installs below $IDF_TOOLS_PATH/tools; EIM instead sets
-- IDF_TOOLS_PATH to the tools directory itself. Try both before the default.
local espressif = vim.fs.normalize(vim.env.IDF_TOOLS_PATH or '~/.espressif')
local tool_roots = { vim.fs.joinpath(espressif, 'tools') }
if vim.env.IDF_TOOLS_PATH then table.insert(tool_roots, espressif) end
local default_tools = vim.fs.normalize '~/.espressif/tools'
if not vim.tbl_contains(tool_roots, default_tools) then table.insert(tool_roots, default_tools) end
local platformio = vim.fs.normalize(vim.env.PLATFORMIO_CORE_DIR or '~/.platformio')

local function newest(pattern)
  local matches = vim.fn.glob(pattern, false, true)
  table.sort(matches)
  return matches[#matches]
end

-- Espressif ships an LLVM build whose clangd knows the Xtensa targets; stock
-- clangd rejects the ESP32/ESP32-S3 compile commands. It is a complete
-- clangd, so prefer it for every project when installed. ESP-IDF
-- Installation Manager splits it into `esp-clangd` (the binary) and
-- `esp-clang-libs` (its builtin headers); `idf_tools.py install esp-clang`
-- installs one `esp-clang` tree that already contains both.
---@return string[] executable and its required arguments
local function clangd_command()
  for _, root in ipairs(tool_roots) do
    local clangd = newest(vim.fs.joinpath(root, 'esp-clangd/*/esp-clangd/bin/clangd'))
    if clangd then
      local version = clangd:match '/esp%-clangd/([^/]+)/'
      local resource_dir = newest(vim.fs.joinpath(root, 'esp-clang-libs', version, 'esp-clang/lib/clang/*'))
      if resource_dir then return { clangd, '--resource-dir=' .. resource_dir } end
    end
    local bundled = newest(vim.fs.joinpath(root, 'esp-clang/*/esp-clang/bin/clangd'))
    if bundled then return { bundled } end
  end
  return { 'clangd' }
end

-- clangd only runs a compiler from compile_commands.json to learn its system
-- include paths when that compiler matches one of these globs (`*` and `**`
-- only). CMake on macOS records Apple's compilers as `/usr/bin/cc`/`c++`.
local query_drivers = {
  '/usr/bin/cc',
  '/usr/bin/c++',
  '/usr/bin/clang*',
  '/usr/bin/gcc*',
  '/usr/bin/g++*',
  '/opt/homebrew/bin/gcc*',
  '/opt/homebrew/bin/g++*',
  platformio .. '/packages/toolchain-*/bin/*-gcc',
  platformio .. '/packages/toolchain-*/bin/*-g++',
}
for _, root in ipairs(tool_roots) do
  table.insert(query_drivers, root .. '/**/bin/*-esp*-elf-*')
  table.insert(query_drivers, root .. '/**/esp-clang/bin/clang*')
end

---@type table<string, vim.lsp.Config>
local servers = {
  clangd = {
    cmd = vim.list_extend(clangd_command(), {
      '--log=error',
      '--background-index',
      '--clang-tidy',
      '--header-insertion=iwyu',
      '--completion-style=detailed',
      '--function-arg-placeholders=true',
      '--fallback-style=llvm',
      '--query-driver=' .. table.concat(query_drivers, ','),
    }),
    on_attach = function(_, bufnr)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = bufnr,
          silent = true,
          desc = 'C: ' .. desc,
        })
      end

      map('n', '<leader>ch', '<cmd>ClangdSwitchSourceHeader<CR>', 'Switch source/[H]eader')
      map('n', '<leader>cT', '<cmd>ClangdTypeHierarchy<CR>', '[T]ype hierarchy')
      map('n', '<leader>cA', '<cmd>ClangdAST<CR>', '[A]ST of current line')
      map('x', '<leader>cA', ':ClangdAST<CR>', '[A]ST of selection')
    end,
  },
}

local cmake_filetypes = { 'c', 'cpp', 'cmake' }

-- Only these keys opt into the canonical root. Changing cwd through
-- project.set lets cmake-tools' DirChanged hook save/reload project sessions;
-- native :CMake* commands keep their documented cwd scope.
local function cmake_command(command)
  return function()
    local root = project.get()
    if vim.fn.getcwd() ~= root and not project.set(root, false) then return end
    vim.cmd(command)
  end
end

---@type dap.Configuration[]
local native_debug_configurations = {
  {
    name = 'Launch executable',
    type = 'codelldb',
    request = 'launch',
    program = function() return require('dap.utils').pick_file { path = project.get() } end,
    cwd = project.get,
    stopOnEntry = false,
  },
  {
    name = 'Attach to process',
    type = 'codelldb',
    request = 'attach',
    pid = function() return require('dap.utils').pick_process() end,
    cwd = project.get,
  },
}

return {
  {
    'mason-org/mason-lspconfig.nvim',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      for name, server in pairs(servers) do
        opts.servers[name] = server
      end
    end,
  },

  -- Commands for clangd's protocol extensions: source/header switching,
  -- AST, type hierarchy, symbol info, memory usage.
  {
    'p00f/clangd_extensions.nvim',
    ft = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    opts = {
      memory_usage = { border = 'rounded' },
      symbol_info = { border = 'rounded' },
    },
  },

  -- Generate, build, run, and debug CMake targets. Builds and runs go
  -- through Overseer so they share the task list with everything else.
  {
    'Civitasv/cmake-tools.nvim',
    ft = cmake_filetypes,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'stevearc/overseer.nvim',
    },
    keys = {
      { '<leader>cmg', cmake_command 'CMakeGenerate', ft = cmake_filetypes, desc = 'CMake: [G]enerate' },
      { '<leader>cmb', cmake_command 'CMakeBuild', ft = cmake_filetypes, desc = 'CMake: [B]uild' },
      { '<leader>cmr', cmake_command 'CMakeRun', ft = cmake_filetypes, desc = 'CMake: [R]un launch target' },
      { '<leader>cmd', cmake_command 'CMakeDebug', ft = cmake_filetypes, desc = 'CMake: [D]ebug launch target' },
      { '<leader>cmt', cmake_command 'CMakeSelectBuildTarget', ft = cmake_filetypes, desc = 'CMake: select build [T]arget' },
      { '<leader>cml', cmake_command 'CMakeSelectLaunchTarget', ft = cmake_filetypes, desc = 'CMake: select [L]aunch target' },
      { '<leader>cmv', cmake_command 'CMakeSelectBuildType', ft = cmake_filetypes, desc = 'CMake: select build [V]ariant' },
      { '<leader>cmp', cmake_command 'CMakeSelectConfigurePreset', ft = cmake_filetypes, desc = 'CMake: select configure [P]reset' },
      { '<leader>cmk', cmake_command 'CMakeSelectKit', ft = cmake_filetypes, desc = 'CMake: select [K]it' },
      { '<leader>cmc', cmake_command 'CMakeClean', ft = cmake_filetypes, desc = 'CMake: [C]lean' },
    },
    opts = {
      cmake_regenerate_on_save = false,
      cmake_build_directory = 'out/${variant:buildType}',
      -- Link the active variant's database into the selected CMake cwd.
      cmake_compile_commands_options = { action = 'soft_link', target = vim.uv.cwd },
      cmake_executor = {
        name = 'overseer',
        opts = {
          new_task_opts = {
            -- Build errors go to the quickfix list; the notifier and
            -- cmake-tools' own progress messages cover the rest.
            components = { { 'on_output_quickfix', open_on_exit = 'failure' }, 'default' },
          },
          on_new_task = function() end,
        },
      },
      cmake_runner = {
        name = 'overseer',
        opts = {
          new_task_opts = {
            components = { { 'open_output', on_start = 'always', direction = 'horizontal', focus = false }, 'default' },
          },
          on_new_task = function() end,
        },
      },
    },
  },

  {
    'mfussenegger/nvim-dap',
    opts = {
      adapters = {
        -- Mason's binary directory is on PATH once Mason has loaded.
        codelldb = { type = 'executable', command = 'codelldb' },
      },
      configurations = {
        c = native_debug_configurations,
        cpp = native_debug_configurations,
      },
    },
  },

  {
    'stevearc/conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.c = { 'clang-format' }
      opts.formatters_by_ft.cpp = { 'clang-format' }

      opts.format_on_save_by_ft = opts.format_on_save_by_ft or {}
      local function format_with_style(bufnr)
        -- Without a project style, clang-format's LLVM defaults would
        -- rewrite whole files in projects that never adopted it.
        if vim.fs.root(bufnr, { '.clang-format', '_clang-format' }) then return { timeout_ms = 1000 } end
      end
      opts.format_on_save_by_ft.c = format_with_style
      opts.format_on_save_by_ft.cpp = format_with_style
    end,
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, tool in ipairs { 'clangd', 'clang-format', 'codelldb' } do
        if not vim.tbl_contains(opts.ensure_installed, tool) then table.insert(opts.ensure_installed, tool) end
      end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { '<leader>cm', group = 'C[M]ake' })
    end,
  },
}
