--[[
--
-- This file is not required for your own configuration,
-- but helps people determine if their system is setup correctly.
--
--]]

local check_version = function()
  local verstr = tostring(vim.version())
  if not vim.version.ge then
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
    return
  end

  if vim.version.ge(vim.version(), '0.12') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to latest stable or nightly", verstr))
  end
end

-- Each row names acceptable executables and the feature that needs them.
local function check_tools(title, tools)
  vim.health.start(title)
  for _, tool in ipairs(tools) do
    local found
    for _, executable in ipairs(tool[1]) do
      if vim.fn.executable(executable) == 1 then
        found = executable
        break
      end
    end
    if found then
      vim.health.ok(('%s: %s'):format(found, tool[2]))
    else
      vim.health.warn(('Missing %s: %s'):format(table.concat(tool[1], ' or '), tool[2]))
    end
  end
end

local function check_external_reqs()
  check_tools('Editor and parser tools', {
    { { 'git' }, 'plugin installation and Git integration' },
    { { 'make' }, 'native plugin builds' },
    { { 'unzip' }, 'Mason package extraction' },
    { { 'rg' }, 'project text search' },
    { { 'fd', 'fdfind' }, 'file search and Python environment discovery' },
    { { 'tree-sitter' }, 'parser builds; version 0.26.1 or newer is required' },
    { { 'cc', 'gcc', 'clang' }, 'parser compilation' },
    { { 'curl' }, 'parser downloads' },
    { { 'tar' }, 'parser archive extraction' },
  })
  vim.health.info 'For parser version and query checks, run :checkhealth nvim-treesitter.'

  check_tools('Language tools (only needed for languages you use)', {
    { { 'cargo' }, 'Rust builds and runnables' },
    { { 'rust-analyzer' }, 'Rust language support through rustaceanvim' },
    { { 'rustfmt' }, 'Rust formatting' },
    { { 'python3' }, 'Python environments and the JDTLS launcher' },
    { { 'java' }, 'Java language support; JDTLS requires a JDK 21 or newer' },
    { { 'cmake' }, 'C/C++ project configuration and builds' },
  })
  vim.health.info 'For language tooling checks, run :checkhealth rustaceanvim or :checkhealth vim.lsp.'
  vim.health.info 'ESP-IDF tools are resolved inside each task’s activated environment; they need not be on Neovim’s PATH.'

  check_tools('Optional document rendering tools', {
    { { 'magick' }, 'Snacks image conversion' },
    { { 'tectonic', 'pdflatex' }, 'rendered LaTeX math' },
    { { 'mmdc' }, 'rendered Mermaid diagrams' },
  })
  vim.health.info 'These rendering tools are only needed for the corresponding content. Run :checkhealth snacks for terminal/image support.'
end

return {
  check = function()
    vim.health.start 'aakash.nvim'

    vim.health.info [[NOTE: Not every warning is a 'must-fix' in `:checkhealth`

  Fix only warnings for plugins and languages you intend to use.
    Mason will give warnings for languages that are not installed.
    You do not need to install, unless you want to use those languages!]]

    local uv = vim.uv or vim.loop
    vim.health.info('System Information: ' .. vim.inspect(uv.os_uname()))

    check_version()
    check_external_reqs()
  end,
}
