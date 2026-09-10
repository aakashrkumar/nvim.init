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

  if vim.version.ge(vim.version(), '0.12.4') then
    vim.health.ok(string.format("Neovim version is: '%s'", verstr))
  else
    vim.health.error(string.format("Neovim out of date: '%s'. Upgrade to 0.12.4 or newer (required by VimTeX)", verstr))
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

  check_tools('LaTeX and Typst authoring tools', {
    { { 'texlab' }, 'LaTeX/BibTeX language support (Mason)' },
    { { 'latexmk' }, 'VimTeX continuous compilation' },
    { { 'pdflatex', 'xelatex', 'lualatex' }, 'LaTeX compilation; install a TeX distribution' },
    { { 'latexindent' }, 'LaTeX formatting through Texlab' },
    { { 'tinymist' }, 'Typst language support, formatting, PDF export, and preview (Mason)' },
  })
  vim.health.info 'LaTeX: TeX Live on Linux, MacTeX on macOS; :checkhealth vimtex checks the compiler and PDF viewer.'
  vim.health.info 'Typst preview shares Mason’s Tinymist and downloads its own websocat; a separate typst CLI is optional.'
  if vim.uv.os_uname().sysname == 'Darwin' then
    local skim = vim.fn.isdirectory '/Applications/Skim.app' == 1 or vim.fn.isdirectory(vim.fn.expand '~/Applications/Skim.app') == 1
    if skim then
      vim.health.ok 'Skim: LaTeX PDF viewer'
    else
      vim.health.warn 'Skim is missing; install with brew install --cask skim for LaTeX PDF viewing.'
    end
    vim.health.info 'For PDF-to-source search, configure Skim’s Sync settings as described in :help vimtex-view-skim'
  elseif vim.uv.os_uname().sysname == 'Linux' then
    check_tools('LaTeX PDF viewer', {
      { { 'zathura' }, 'VimTeX PDF viewing and SyncTeX navigation' },
    })
  end

  check_tools('Optional document rendering tools', {
    { { 'magick' }, 'Snacks image conversion' },
    { { 'tectonic', 'pdflatex' }, 'rendered LaTeX math' },
    { { 'mmdc' }, 'rendered Mermaid diagrams' },
  })
  vim.health.info 'These rendering tools are only needed for the corresponding content. Run :checkhealth snacks for terminal/image support.'

  local profiling_tools = {
    { { 'samply' }, 'optional local CPU captures and browser profiles' },
  }
  local linux = vim.uv.os_uname().sysname == 'Linux'
  local macos = vim.uv.os_uname().sysname == 'Darwin'
  if linux then table.insert(profiling_tools, { { 'perf' }, 'optional Linux captures and PerfAnno annotations' }) end
  if macos then table.insert(profiling_tools, { { 'cargo-instruments' }, 'optional macOS Rust captures in Apple Instruments' }) end
  check_tools('Optional profiling tools', profiling_tools)
  vim.health.info 'Profiling tools are only needed when capturing or opening profiles; no system settings are changed automatically.'
  vim.health.info(
    'Captures are retained in ' .. vim.fs.joinpath(vim.fn.stdpath 'cache', 'profiling') .. '; Instruments and perf/DWARF recordings can grow quickly.'
  )
  if macos then
    if vim.fn.executable 'xcrun' == 1 then
      local result = vim.system({ 'xcrun', '--find', 'xctrace' }, { text = true }):wait(5000)
      if result.code == 0 then
        vim.health.ok('Apple trace recorder: ' .. vim.trim(result.stdout))
      else
        vim.health.warn 'xctrace is unavailable; Instruments needs full Xcode selected, not just the Command Line Tools.'
      end
    else
      vim.health.warn 'Missing xcrun; Instruments requires full Xcode.'
    end
    vim.health.info 'Install cargo-instruments with cargo install cargo-instruments; inspect Xcode selection with xcode-select --print-path.'
    vim.health.info 'cargo-instruments prepares debug symbols and ad-hoc signs Apple Silicon build outputs using its native defaults.'
  end
  if linux then
    vim.health.info 'For truncated perf callgraphs from LLD-built Rust code, an opt-in workaround is -C link-arg=-Wl,--no-rosegment. Other linkers may reject it.'
    vim.health.info 'Task RUSTFLAGS overrides configured rustflags and can trigger rebuilds. Preserve existing flags when adding a linker workaround.'
  end
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
