return {
    -- ============================================================
    -- DEBUGGING
    -- Shared DAP UI, lifecycle, and keymaps
    -- ============================================================

    -- nvim-dap has no `setup()`. Language modules add adapters and
    -- configurations through these merged `opts` (mirroring the `servers`
    -- registry in `lsp.lua`) and `config` copies them onto nvim-dap, so no
    -- module needs its own `config` on this plugin.
    {
        'mfussenegger/nvim-dap',
        opts = {
            ---@type table<string, dap.Adapter|fun(callback: fun(adapter: dap.Adapter), config: dap.Configuration)>
            adapters = {},
            -- Keyed by filetype. See `:help dap-configuration`.
            ---@type table<string, dap.Configuration[]>
            configurations = {},
            -- Compute configurations per buffer, e.g. only inside a certain kind
            -- of project. See `:help dap-providers-configs`.
            ---@type table<string, fun(bufnr: integer): dap.Configuration[]>
            providers = {},
        },
        config = function(_, opts)
            local dap = require 'dap'
            for name, adapter in pairs(opts.adapters) do
                dap.adapters[name] = adapter
            end
            for filetype, configurations in pairs(opts.configurations) do
                dap.configurations[filetype] = configurations
            end
            for name, provider in pairs(opts.providers) do
                dap.providers.configs[name] = provider
            end
        end,
    },

    {
        'igorlfs/nvim-dap-view',
        version = '1.*',
        lazy = false,
        dependencies = { 'mfussenegger/nvim-dap' },
        config = function()
            local dap = require 'dap'
            local dapview = require 'dap-view'

            local controls = { 'play', 'step_over', 'step_into', 'step_out', 'terminate', 'disconnect' }
            local sections = {
                { id = 'scopes', name = 'Variables', short = 'Vars', key = 'S' },
                { id = 'watches', name = 'Watches', short = 'Watch', key = 'W' },
                { id = 'threads', name = 'Call stack', short = 'Stack', key = 'T' },
                { id = 'breakpoints', name = 'Breakpoints', short = 'BP', key = 'B' },
                { id = 'exceptions', name = 'Exceptions', short = 'EX', key = 'E' },
                { id = 'repl', name = 'REPL', short = 'REPL', key = 'R' },
            }
            -- The native winbar has one line. Keep names until they no longer fit,
            -- then shorten less-used tabs first and the selected tab last.
            local full_width = #controls * 3 -- one-cell icons, with a space on each side
            for _, section in ipairs(sections) do
                section.labels = { section.name .. ' [' .. section.key .. ']', section.short .. ':' .. section.key, section.key }
                section.widths = {}
                for tier, label in ipairs(section.labels) do
                    section.widths[tier] = vim.fn.strdisplaywidth(label)
                end
                full_width = full_width + section.widths[1] + 2
            end

            local cached_width, cached_current, cached_labels
            local function fitted_labels(width, current)
                if width == cached_width and current == cached_current then return cached_labels end
                local labels, active, used = {}, nil, full_width
                for index, section in ipairs(sections) do
                    labels[index] = section.labels[1]
                    if section.id == current then active = index end
                end
                for tier = 2, 3 do
                    for index = #sections, 1, -1 do
                        if used <= width then break end
                        if index ~= active then
                            local section = sections[index]
                            used = used - section.widths[tier - 1] + section.widths[tier]
                            labels[index] = section.labels[tier]
                        end
                    end
                end
                if used > width and active then
                    local section = sections[active]
                    for tier = 2, 3 do
                        if used <= width then break end
                        used = used - section.widths[tier - 1] + section.widths[tier]
                        labels[active] = section.labels[tier]
                    end
                end
                cached_width, cached_current, cached_labels = width, current, labels
                return labels
            end

            local section_order, base_sections = {}, {}
            for index, section in ipairs(sections) do
                local slot = index
                local full_name = section.labels[1]
                section_order[index] = section.id
                base_sections[section.id] = {
                    keymap = section.key,
                    label = function(width, current) return width == 0 and full_name or fitted_labels(width, current)[slot] end,
                }
            end

            local function sidebar_width()
                local preferred = math.max(full_width, math.floor(vim.o.columns * 0.38))
                local limit = math.max((#sections + #controls) * 3, math.floor(vim.o.columns / 2))
                return math.min(preferred, limit)
            end

            dapview.setup {
                winbar = {
                    sections = section_order,
                    default_section = 'scopes',
                    show_keymap_hints = false, -- the fitted labels already contain their keys
                    base_sections = base_sections,
                    controls = {
                        enabled = true,
                        buttons = controls,
                    },
                },
                windows = {
                    -- Prefer full names on wide screens; normally reserve at least half
                    -- the editor for source, with a minimum width for controls and key tabs.
                    -- Dap-view reapplies its opening width when windows open/close, including floats.
                    -- This policy sets that width; ad-hoc resizing can be undone by a popup.
                    size = sidebar_width,
                    position = 'right',
                    terminal = { size = 0.31, position = 'below' },
                },
                hover = { border = 'rounded' },
                help = { border = 'rounded' },
                virtual_text = {
                    enabled = true,
                    position = 'eol',
                    -- Preserve the adapter's full value summary and type without imposing
                    -- a character limit. Keep multiline summaries on a single source line.
                    format = function(variable)
                        local value = ' ' .. variable.value:gsub('[\r\n]+', ' ↵ ')
                        if variable.type and variable.type ~= '' then return value .. ' : ' .. variable.type end
                        return value
                    end,
                    suffix = function(position, _, _, index, count)
                        if position ~= 'inline' then return index < count and ', ' or '' end
                    end,
                },
                auto_toggle = 'keep_terminal',
                follow_tab = true,
            }

            -- Dap-view refreshes labels on section changes, but not pane resizes.
            vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
                group = vim.api.nvim_create_augroup('aakash-dap-layout', { clear = true }),
                callback = function()
                    local winbar = package.loaded['dap-view.options.winbar']
                    if not winbar then return end
                    winbar.refresh_winbar()
                end,
            })

            -- Reuse visible source buffers, otherwise open a safe tab rather than
            -- replacing a debugger pane. The dock follows native DAP source jumps.
            dap.defaults.fallback.switchbuf = 'usevisible,usetab,newtab'

            -- Keep debugger surfaces distinct from source windows. BufWinEnter also
            -- covers reused REPL/console buffers after a session or layout change.
            local titles = { ['dap-view'] = 'Debug inspector', ['dap-view-term'] = 'Program output', ['dap-repl'] = 'Debug REPL' }
            local diagnostics = require 'aakash.diagnostics'
            vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
                group = vim.api.nvim_create_augroup('aakash-dap-statusline', { clear = true }),
                callback = function(event)
                    local filetype = vim.bo[event.buf].filetype
                    if filetype ~= 'dap-repl' and not filetype:match '^dap%-view' then return end
                    if titles[filetype] and not vim.b[event.buf].ministatusline_config then
                        local text = '%#DapViewStatusLine# ' .. titles[filetype] .. ' %='
                        local function content() return text .. diagnostics.section() .. ' ' end
                        vim.b[event.buf].ministatusline_config = { content = { active = content, inactive = content } }
                    end
                    for _, win in ipairs(vim.fn.win_findbuf(event.buf)) do
                        vim.wo[win][0].winhighlight =
                            'Normal:DapViewNormal,NormalNC:DapViewNormal,NormalFloat:DapViewNormal,FloatBorder:DapViewSeparator,CursorLine:DapViewCursorLine,WinSeparator:DapViewSeparator'
                        vim.wo[win][0].fillchars = 'eob: '
                    end
                end,
            })

            local function set_debug_highlights()
                for name, link in pairs {
                    DapBreakpoint = 'DiagnosticError',
                    DapBreakpointCondition = 'DiagnosticWarn',
                    DapLogPoint = 'DiagnosticInfo',
                    DapBreakpointRejected = 'Comment',
                    DapStopped = 'DiagnosticWarn',
                    DapStoppedLine = 'DiagnosticVirtualTextWarn',
                } do
                    vim.api.nvim_set_hl(0, name, { link = link })
                end
            end
            set_debug_highlights()
            vim.api.nvim_create_autocmd('ColorScheme', {
                group = vim.api.nvim_create_augroup('aakash-dap-highlights', { clear = true }),
                callback = set_debug_highlights,
            })
            for name, text in pairs {
                DapBreakpoint = '●',
                DapBreakpointCondition = '◆',
                DapLogPoint = '◉',
                DapBreakpointRejected = '○',
                DapStopped = '▶',
            } do
                vim.fn.sign_define(name, {
                    text = text,
                    texthl = name,
                    numhl = name,
                    linehl = name == 'DapStopped' and 'DapStoppedLine' or '',
                })
            end

            local debug_step_keymaps = {
                { '<Down>', dap.step_over, '[D]ebug: step [O]ver' },
                { '<Right>', dap.step_into, '[D]ebug: step [I]nto' },
                { '<Left>', dap.step_out, '[D]ebug: step [O]ut' },
                { '<Up>', dap.restart_frame, '[D]ebug: [R]estart frame' },
            }

            -- Follow DAP's session lifecycle, including disconnects and adapter failures.
            -- Keep the mappings while another session is still alive, and restore the
            -- original global mappings after the last one closes. Buffer maps stay local.
            local saved_step_keymaps
            dap.listeners.on_session.aakash_dap_step_keys = vim.schedule_wrap(function()
                -- Read the current session after scheduling: a queued close must not
                -- restore the arrows if another session has already taken its place.
                if dap.session() then
                    if saved_step_keymaps then return end
                    saved_step_keymaps = {}
                    for _, mapping in ipairs(vim.api.nvim_get_keymap 'n') do
                        for _, keymap in ipairs(debug_step_keymaps) do
                            if mapping.lhs == keymap[1] then saved_step_keymaps[keymap[1]] = mapping end
                        end
                    end
                    for _, keymap in ipairs(debug_step_keymaps) do
                        vim.keymap.set('n', keymap[1], keymap[2], { silent = true, desc = keymap[3] })
                    end
                elseif saved_step_keymaps then
                    for _, keymap in ipairs(debug_step_keymaps) do
                        pcall(vim.keymap.del, 'n', keymap[1])
                        local previous = saved_step_keymaps[keymap[1]]
                        if previous then vim.fn.mapset('n', false, previous) end
                    end
                    saved_step_keymaps = nil
                end
            end)

            local function prompt_breakpoint(prompt, apply)
                local bufnr = vim.api.nvim_get_current_buf()
                local line = vim.api.nvim_win_get_cursor(0)[1]
                vim.ui.input({ prompt = prompt }, function(value)
                    if value == nil then return end
                    if not vim.api.nvim_buf_is_loaded(bufnr) or line > vim.api.nvim_buf_line_count(bufnr) then
                        vim.notify('Breakpoint source is no longer available', vim.log.levels.WARN)
                        return
                    end
                    -- The input UI may change the current buffer/window before returning.
                    -- DAP's public breakpoint API operates on the current source line.
                    vim.api.nvim_buf_call(bufnr, function()
                        local view = vim.fn.winsaveview()
                        vim.api.nvim_win_set_cursor(0, { line, 0 })
                        local ok, err = pcall(apply, value)
                        vim.fn.winrestview(view)
                        if not ok then error(err) end
                    end)
                end)
            end

            vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, {
                desc = '[D]ebug: toggle [B]reakpoint',
            })

            vim.keymap.set('n', '<leader>dB', function()
                prompt_breakpoint('Breakpoint condition: ', function(value) dap.set_breakpoint(value) end)
            end, {
                desc = '[D]ebug: conditional [B]reakpoint',
            })

            vim.keymap.set('n', '<leader>dh', function()
                prompt_breakpoint('Hit condition (e.g. 10): ', function(value) dap.set_breakpoint(nil, value) end)
            end, {
                desc = '[D]ebug: breakpoint [H]it condition',
            })

            vim.keymap.set('n', '<leader>dl', function()
                prompt_breakpoint('Log message ({expression} is evaluated): ', function(value) dap.set_breakpoint(nil, nil, value) end)
            end, {
                desc = '[D]ebug: [L]og point',
            })

            vim.keymap.set('n', '<leader>dr', function()
                dapview.open()
                dapview.jump_to_view 'repl'
            end, {
                desc = '[D]ebug: open [R]EPL',
            })

            vim.keymap.set({ 'n', 'x' }, '<leader>de', function() dapview.hover(nil, false) end, {
                desc = '[D]ebug: [E]valuate expression (repeat to focus)',
            })

            vim.keymap.set({ 'n', 'x' }, '<leader>dw', dapview.add_expr, {
                desc = '[D]ebug: [W]atch expression',
            })

            vim.keymap.set('n', '<leader>dC', dap.run_to_cursor, {
                desc = '[D]ebug: run to [C]ursor',
            })

            vim.keymap.set('n', '<leader>dk', dap.up, {
                desc = '[D]ebug: stack up',
            })

            vim.keymap.set('n', '<leader>dj', dap.down, {
                desc = '[D]ebug: stack down',
            })

            vim.keymap.set('n', '<leader>dc', dap.continue, {
                desc = '[D]ebug: [C]ontinue',
            })

            vim.keymap.set('n', '<leader>di', dap.step_into, {
                desc = '[D]ebug: step [I]nto',
            })

            vim.keymap.set('n', '<leader>do', dap.step_over, {
                desc = '[D]ebug: step [O]ver',
            })

            vim.keymap.set('n', '<leader>dO', dap.step_out, {
                desc = '[D]ebug: step [O]ut',
            })

            vim.keymap.set('n', '<leader>dt', dap.terminate, {
                desc = '[D]ebug: [T]erminate',
            })

            vim.keymap.set('n', '<leader>du', function() dapview.toggle(true) end, {
                desc = '[D]ebug: toggle [U]I',
            })

            vim.keymap.set('n', '<leader>dU', function() dapview.close(true) end, {
                desc = '[D]ebug: hide [U]I and console (keep session)',
            })
        end,
    },

    {
        'folke/which-key.nvim',
        opts = function(_, opts)
            opts.spec = opts.spec or {}
            table.insert(opts.spec, { '<leader>d', group = '[D]ebug' })
        end,
    },
}
