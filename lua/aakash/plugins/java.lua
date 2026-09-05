-- ============================================================
-- JAVA
-- Language server, refactors, formatting, debugging, and tests
-- ============================================================

local function java_bundles()
  local bundles = {}
  -- Resolve Mason's public root after setup, not while importing this spec.
  local mason_root = vim.env.MASON
  if not mason_root then return bundles end

  local seen = {}
  local function add_bundle(jar)
    -- Mason may expose versioned and stable names for the same physical JAR.
    local realpath = vim.uv.fs_realpath(jar)
    if realpath and not seen[realpath] then
      seen[realpath] = true
      bundles[#bundles + 1] = realpath
    end
  end
  add_bundle(mason_root .. '/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar')

  -- Keep the test JAR exclusions documented by nvim-jdtls.
  local excluded_test_jars = {
    ['com.microsoft.java.test.runner-jar-with-dependencies.jar'] = true,
    ['jacocoagent.jar'] = true,
  }
  for _, jar in ipairs(vim.fn.glob(mason_root .. '/share/java-test/*.jar', false, true)) do
    if not excluded_test_jars[vim.fs.basename(jar)] then add_bundle(jar) end
  end
  return bundles
end

local function jdtls_workspace(root_dir)
  local root = vim.fs.normalize(vim.uv.fs_realpath(root_dir) or root_dir)
  local project = vim.fs.basename(root)
  local hash = vim.fn.sha256(root):sub(1, 8)
  return vim.fs.joinpath(vim.fn.stdpath 'cache', 'jdtls', project .. '-' .. hash)
end

local function start_jdtls(dispatchers, config)
  local root_dir = config.root_dir or vim.fn.getcwd()
  local cmd = {
    'jdtls',
    '-data',
    jdtls_workspace(root_dir),
  }

  local mason_root = vim.env.MASON
  if mason_root then
    local lombok_jar = mason_root .. '/share/jdtls/lombok.jar'
    if vim.uv.fs_stat(lombok_jar) then table.insert(cmd, 2, '--jvm-arg=-javaagent:' .. lombok_jar) end
  end

  return vim.lsp.rpc.start(cmd, dispatchers, {
    cwd = config.cmd_cwd,
    env = config.cmd_env,
    detached = config.detached,
  })
end

-- nvim-lspconfig and nvim-jdtls both ship lsp/jdtls.lua with different defaults.
-- Pin the command and root markers instead of depending on runtimepath order.
---@type vim.lsp.Config
local server = {
  cmd = start_jdtls,
  filetypes = { 'java' },
  root_markers = {
    { 'mvnw', 'gradlew', 'settings.gradle', 'settings.gradle.kts', '.git' },
    { 'build.xml', 'pom.xml', 'build.gradle', 'build.gradle.kts' },
  },
  before_init = function(params)
    params.initializationOptions = params.initializationOptions or {}
    params.initializationOptions.bundles = java_bundles()
  end,
  settings = {
    java = {
      -- The shared inlay-hint mapping controls whether these are visible.
      inlayHints = {
        parameterNames = {
          enabled = 'all',
        },
      },
    },
  },
  on_attach = function(_, bufnr)
    local jdtls = require 'jdtls'
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        buffer = bufnr,
        silent = true,
        desc = 'Java: ' .. desc,
      })
    end

    map('n', '<leader>co', jdtls.organize_imports, 'Organize imports')
    map('n', '<leader>cxv', jdtls.extract_variable_all, 'Extract variable')
    map('x', '<leader>cxv', "<Esc><Cmd>lua require('jdtls').extract_variable_all(true)<CR>", 'Extract variable')
    map('n', '<leader>cxc', jdtls.extract_constant, 'Extract constant')
    map('x', '<leader>cxc', "<Esc><Cmd>lua require('jdtls').extract_constant(true)<CR>", 'Extract constant')
    map('x', '<leader>cxm', "<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>", 'Extract method')
    map('n', '<leader>dJt', jdtls.test_nearest_method, 'Debug nearest test')
    map('n', '<leader>dJc', jdtls.test_class, 'Debug test class')
  end,
}

return {
  {
    'mfussenegger/nvim-jdtls',
    lazy = false,
    dependencies = { 'mfussenegger/nvim-dap' },
  },

  {
    'mason-org/mason-lspconfig.nvim',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.jdtls = server
    end,
  },

  {
    'stevearc/conform.nvim',
    opts = {
      -- No external formatter: Conform falls back to JDTLS for Java.
      format_on_save_by_ft = {
        java = { timeout_ms = 3000 },
      },
    },
  },

  {
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, tool in ipairs { 'jdtls', 'java-debug-adapter', 'java-test' } do
        if not vim.tbl_contains(opts.ensure_installed, tool) then table.insert(opts.ensure_installed, tool) end
      end
    end,
  },

  {
    'folke/which-key.nvim',
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      vim.list_extend(opts.spec, {
        { '<leader>cx', group = 'E[x]tract', mode = { 'n', 'x' } },
        { '<leader>dJ', group = 'Debug [J]ava' },
      })
    end,
  },
}
