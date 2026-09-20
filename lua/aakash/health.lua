-- [[ Configuration health ]]
-- Run :checkhealth aakash to check Neovim and external tools.
-- Warnings are grouped by feature; install only the tools you intend to use.
-- Plugins provide their own detailed checks alongside this overview.

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
        { { 'rustup' }, 'stable rust-analyzer and project-selected Rust toolchains' },
        { { 'rustfmt' }, 'Rust formatting' },
        { { 'python3' }, 'Python environments and the JDTLS launcher' },
        { { 'java' }, 'Java language support; JDTLS requires a JDK 21 or newer' },
        { { 'cmake' }, 'C/C++ project configuration and builds' },
    })
    vim.health.info 'For language tooling checks, run :checkhealth rustaceanvim or :checkhealth vim.lsp.'
    vim.health.info 'CMake ESP-IDF tasks activate their SDK environment; Cargo firmware tasks inherit the shell/project environment.'

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

local function check_esp_rust()
    check_tools('ESP Rust device tools (only needed for your chosen workflow)', {
        { { 'espflash' }, 'Cargo serial flashing and monitoring' },
        { { 'probe-rs' }, 'JTAG flashing, debugging, on-device tests and RTT' },
    })
    vim.health.start 'Rust analyzer and ESP firmware project'
    local ok, analyzer = pcall(function() return require('aakash.rust').analyzer_command() end)
    if ok then
        vim.health.ok('Stable analyzer: ' .. analyzer[1])
    else
        vim.health.error(tostring(analyzer))
    end

    local root = require('aakash.project').get()
    local project, err = require('aakash.esp32').project(root)
    if not project then
        if err then
            vim.health.warn(err)
        else
            vim.health.info 'No ESP Cargo project at the current project root; open firmware to check its compiler, target and SDK requirements.'
        end
        return
    end
    vim.health.info(('Project: %s (%s)'):format(project.root, project.sdk == 'idf' and 'ESP-IDF/std' or 'esp-hal/no_std'))

    local function output(command, env)
        if vim.fn.executable(command[1]) ~= 1 then return nil, command[1] .. ' is not on PATH' end
        local inspection_env = vim.tbl_extend('force', env or {}, { RUSTUP_AUTO_INSTALL = '0' })
        local result = vim.system(command, { cwd = project.cwd, env = inspection_env, text = true }):wait(5000)
        if result.code ~= 0 then return nil, vim.trim(result.stderr or 'command failed') end
        return vim.trim(result.stdout)
    end
    local toolchain, toolchain_err = output { 'rustup', 'show', 'active-toolchain' }
    if toolchain then
        vim.health.ok('Cargo shell toolchain: ' .. toolchain)
    else
        vim.health.warn('Project toolchain: ' .. toolchain_err)
    end
    local extra_env = vim.tbl_get(project.settings, 'cargo', 'extraEnv')
    if extra_env and next(extra_env) then vim.health.info('Analyzer Cargo environment overrides: ' .. vim.inspect(extra_env)) end
    local compiler, compiler_err = output({ 'rustc', '--version' }, extra_env)
    if compiler then
        vim.health.ok('Analyzer project compiler: ' .. compiler)
    else
        vim.health.warn('Project compiler: ' .. compiler_err)
        return
    end

    local sysroot, sysroot_err = output({ 'rustc', '--print', 'sysroot' }, extra_env)
    if not sysroot then
        vim.health.warn('Project sysroot: ' .. sysroot_err)
        return
    end
    local macro_server = vim.tbl_get(project.settings, 'procMacro', 'server')
        or vim.fs.joinpath(sysroot, 'libexec', 'rust-analyzer-proc-macro-srv' .. (vim.fn.has 'win32' == 1 and '.exe' or ''))
    if vim.fn.executable(macro_server) == 1 then
        vim.health.ok('Project proc-macro server: ' .. macro_server)
    else
        vim.health.warn(
            'No project proc-macro server at '
                .. macro_server
                .. '; install/update this toolchain’s rust-analyzer component or set rust-analyzer.procMacro.server.'
        )
    end

    local target = project.target
    if type(target) == 'string' then
        local targets = output({ 'rustc', '--print', 'target-list' }, extra_env)
        if targets and not vim.tbl_contains(vim.split(targets, '\n', { plain = true }), target) and not target:match '%.json$' then
            vim.health.error(('Project compiler does not support %s; check rust-toolchain.toml and rust-analyzer.cargo.extraEnv.'):format(target))
        elseif vim.uv.fs_stat(vim.fs.joinpath(sysroot, 'lib', 'rustlib', target, 'lib')) then
            vim.health.ok('Installed target libraries: ' .. target)
        elseif vim.uv.fs_stat(vim.fs.joinpath(sysroot, 'lib', 'rustlib', 'src', 'rust', 'library')) then
            vim.health.info(target .. ': no prebuilt libraries; rust-src is present, so the project can use Cargo build-std.')
        else
            vim.health.warn(target .. ': install the target libraries, or rust-src for a project using build-std.')
        end
    else
        vim.health.info 'Cargo owns target selection. Set rust-analyzer.cargo.target in project settings to check the same target here and in the editor.'
    end

    if type(target) == 'string' and target:match '^xtensa' then
        check_tools('Xtensa shell environment', {
            { { 'xtensa-esp-elf-gcc', 'xtensa-' .. (target:match '^xtensa%-([^-]+)' or 'esp32') .. '-elf-gcc' }, 'Xtensa linker exported by espup' },
        })
        if vim.env.LIBCLANG_PATH and vim.uv.fs_stat(vim.env.LIBCLANG_PATH) then
            vim.health.ok('LIBCLANG_PATH: ' .. vim.env.LIBCLANG_PATH)
        else
            vim.health.warn 'Source your espup export-esp.sh in the shell before launching Neovim; LIBCLANG_PATH is not usable.'
        end
    end
    if project.sdk == 'idf' then
        check_tools('ESP-IDF/std build prerequisites', {
            { { 'ldproxy' }, 'Rust ESP-IDF linker proxy' },
            { { 'cmake' }, 'ESP-IDF build configuration' },
            { { 'ninja' }, 'ESP-IDF builds' },
            { { 'python3' }, 'ESP-IDF build tooling' },
        })
        if vim.env.IDF_PATH then
            vim.health.warn('Ambient IDF_PATH=' .. vim.env.IDF_PATH .. ' overrides esp-idf-sys SDK selection; keep it intentional for this project.')
        else
            vim.health.info 'esp-idf-sys manages the SDK selected by the project; no global ESP-IDF activation is required.'
        end
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
        check_esp_rust()
    end,
}
