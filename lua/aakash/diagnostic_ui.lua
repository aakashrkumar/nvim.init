local M = {}

M.namespace = vim.api.nvim_create_namespace("aakash-cursor-diagnostic")

local enabled = true
local rendered_bufnr
local minimum_message_width = 4
local severity_highlights = {
	[vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
	[vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
	[vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
	[vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
}

local function trim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function truncate_display(value, max_width)
	if vim.fn.strdisplaywidth(value) <= max_width then
		return value
	end

	local result = ""
	local suffix = "…"
	for index = 0, vim.fn.strchars(value) - 1 do
		local character = vim.fn.strcharpart(value, index, 1)
		if vim.fn.strdisplaywidth(result .. character .. suffix) > max_width then
			break
		end
		result = result .. character
	end
	return result .. suffix
end

local function sanitize_line(line, diagnostic)
	local message = trim(line)
	message = message:gsub("^`?#%[warn%b()%]`?%s+on by default%s*$", "")
	message = message:gsub("^`?#%[warn%b()%]`?%s*$", "")
	message = message:gsub("%s*for further information visit%s+https?://%S+.*$", "")
	message = message:gsub("https?://%S+", "")
	message = message:gsub("%s+`#%[warn%b()%]`.*$", "")
	message = message:gsub("%s+#%[warn%b()%].*$", "")
	if diagnostic.code then
		local code_suffix = " [" .. tostring(diagnostic.code) .. "]"
		if message:sub(-#code_suffix) == code_suffix then
			message = message:sub(1, #message - #code_suffix)
		end
	end
	return trim(message:gsub("%s+", " "))
end

local function split_display_line(value, max_width)
	local prefix = ""
	local char_count = vim.fn.strchars(value)
	local last_break
	for index = 0, char_count - 1 do
		local character = vim.fn.strcharpart(value, index, 1)
		if vim.fn.strdisplaywidth(prefix .. character) > max_width then
			if prefix == "" then
				return character, vim.fn.strcharpart(value, index + 1)
			end
			if character:match("%s") then
				return (prefix:gsub("%s+$", "")), (vim.fn.strcharpart(value, index + 1):gsub("^%s+", ""))
			end
			if last_break and last_break > 0 then
				return (vim.fn.strcharpart(value, 0, last_break):gsub("%s+$", "")),
					(vim.fn.strcharpart(value, last_break):gsub("^%s+", ""))
			end
			return prefix, vim.fn.strcharpart(value, index)
		end
		prefix = prefix .. character
		if character:match("%s") and prefix:find("%S") then
			last_break = index
		end
	end
	return value, ""
end

local function wrap_line(value, max_width)
	max_width = math.max(minimum_message_width, max_width)
	if value == "" then
		return { "" }
	end

	local wrapped = {}
	local remaining = value
	while vim.fn.strdisplaywidth(remaining) > max_width do
		local line, suffix = split_display_line(remaining, max_width)
		wrapped[#wrapped + 1] = line
		remaining = suffix
	end
	wrapped[#wrapped + 1] = remaining
	return wrapped
end

function M.format_summary(diagnostic, max_width)
	for line in tostring(diagnostic.message or ""):gmatch("[^\r\n]+") do
		local message = sanitize_line(line, diagnostic)
		if message ~= "" then
			return truncate_display(message, math.max(minimum_message_width, max_width))
		end
	end
	return ""
end

function M.wrap_message(message, max_width)
	local wrapped = {}
	for _, line in ipairs(vim.split(tostring(message or ""), "\n", { plain = true })) do
		line = line:gsub("\r$", "")
		vim.list_extend(wrapped, wrap_line(line, max_width))
	end
	return wrapped
end

function M.select_diagnostic(diagnostics)
	local selected
	for _, diagnostic in ipairs(diagnostics or {}) do
		local severity = diagnostic.severity or vim.diagnostic.severity.HINT
		local selected_severity = selected and (selected.severity or vim.diagnostic.severity.HINT)
		if
			not selected
			or severity < selected_severity
			or (severity == selected_severity and (diagnostic.col or 0) < (selected.col or 0))
		then
			selected = diagnostic
		end
	end
	return selected
end

local function window_text_width(winid)
	local info = vim.fn.getwininfo(winid)[1]
	local text_offset = info and info.textoff or 0
	return math.max(12, vim.api.nvim_win_get_width(winid) - text_offset)
end

local function diagnostics_by_line(bufnr, cursor_line)
	local diagnostics = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
		local line = diagnostic.lnum
		local severity = diagnostic.severity or vim.diagnostic.severity.HINT
		local namespace_enabled = diagnostic.namespace == nil
			or vim.diagnostic.is_enabled({ bufnr = bufnr, ns_id = diagnostic.namespace })
		if
			line
			and namespace_enabled
			and (
				severity == vim.diagnostic.severity.ERROR
				or (line == cursor_line and severity == vim.diagnostic.severity.WARN)
			)
		then
			diagnostics[line] = diagnostics[line] or {}
			diagnostics[line][#diagnostics[line] + 1] = diagnostic
		end
	end
	return diagnostics
end

local function virtual_lines(diagnostic, width, expanded)
	local highlight = severity_highlights[diagnostic.severity] or "DiagnosticVirtualTextHint"
	local prefix = " ● "
	local continuation = string.rep(" ", vim.fn.strdisplaywidth(prefix))
	local message_width = math.max(minimum_message_width, width - vim.fn.strdisplaywidth(prefix) - 1)
	local messages
	if expanded then
		messages = M.wrap_message(diagnostic.message, message_width)
	else
		local summary = M.format_summary(diagnostic, message_width)
		if summary == "" then
			return
		end
		messages = { summary }
	end

	local lines = {}
	for index, message in ipairs(messages) do
		lines[#lines + 1] = {
			{ index == 1 and prefix or continuation, highlight },
			{ message, highlight },
		}
	end
	return lines
end

local function clear_presentation()
	if rendered_bufnr and vim.api.nvim_buf_is_valid(rendered_bufnr) then
		vim.api.nvim_buf_clear_namespace(rendered_bufnr, M.namespace, 0, -1)
	end
	rendered_bufnr = nil
end

local function render_current_window()
	clear_presentation()
	if not enabled then
		return
	end

	local winid = vim.api.nvim_get_current_win()
	if not vim.api.nvim_win_is_valid(winid) then
		return
	end
	local bufnr = vim.api.nvim_win_get_buf(winid)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.diagnostic.is_enabled({ bufnr = bufnr }) then
		return
	end

	-- Virtual lines affect layout, so Neovim cannot render them as ephemeral decorations.
	-- Keep the owned marks visible only in the active window instead.
	vim.api.nvim__ns_set(M.namespace, { wins = { winid } })
	rendered_bufnr = bufnr
	local cursor_line = vim.api.nvim_win_get_cursor(winid)[1] - 1
	local width = window_text_width(winid)
	local diagnostics = diagnostics_by_line(bufnr, cursor_line)
	local diagnostic_lines = vim.tbl_keys(diagnostics)
	table.sort(diagnostic_lines)
	for _, line in ipairs(diagnostic_lines) do
		local diagnostic = M.select_diagnostic(diagnostics[line])
		if diagnostic then
			local lines = virtual_lines(diagnostic, width, line == cursor_line)
			if lines then
				vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line, 0, {
					virt_lines = lines,
					virt_lines_overflow = "trunc",
					hl_mode = "combine",
					priority = 2048,
				})
			end
		end
	end
end

local function redraw(bufnr)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim__redraw({ buf = bufnr, valid = false })
	else
		vim.api.nvim__redraw({ valid = false })
	end
end

function M.refresh(bufnr)
	render_current_window()
	redraw(bufnr or vim.api.nvim_get_current_buf())
end

function M.is_enabled()
	return enabled
end

function M.toggle()
	enabled = not enabled
	M.refresh()
	return enabled
end

function M.setup()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
		end
	end

	local group = vim.api.nvim_create_augroup("aakash-cursor-diagnostic", { clear = true })
	vim.api.nvim_create_autocmd({
		"DiagnosticChanged",
		"CursorMoved",
		"CursorMovedI",
		"BufEnter",
		"WinEnter",
		"WinLeave",
		"WinResized",
		"WinScrolled",
	}, {
		group = group,
		callback = function(event)
			M.refresh(event.buf)
		end,
	})
	vim.keymap.set("n", "<leader>td", M.toggle, {
		desc = "[T]oggle cursor [D]iagnostic",
	})
	vim.schedule(M.refresh)
end

return M
