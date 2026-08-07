local M = {}

M.namespace = vim.api.nvim_create_namespace("aakash-cursor-diagnostic")

local enabled = true
local max_message_width = 64
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

function M.format_message(diagnostic)
	for line in tostring(diagnostic.message or ""):gmatch("[^\r\n]+") do
		local message = sanitize_line(line, diagnostic)
		if message ~= "" then
			return truncate_display(message, max_message_width)
		end
	end
	return ""
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

local function enabled_diagnostics(bufnr, line)
	local diagnostics = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = line })) do
		if
			diagnostic.namespace == nil or vim.diagnostic.is_enabled({ bufnr = bufnr, ns_id = diagnostic.namespace })
		then
			diagnostics[#diagnostics + 1] = diagnostic
		end
	end
	return diagnostics
end

local function decoration_for_window(winid, bufnr)
	if
		not enabled
		or not vim.api.nvim_buf_is_valid(bufnr)
		or winid ~= vim.api.nvim_get_current_win()
		or not vim.diagnostic.is_enabled({ bufnr = bufnr })
	then
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(winid)[1] - 1
	local diagnostic = M.select_diagnostic(enabled_diagnostics(bufnr, cursor_line))
	if not diagnostic then
		return
	end

	local message = M.format_message(diagnostic)
	if message == "" then
		return
	end

	local highlight = severity_highlights[diagnostic.severity] or "DiagnosticVirtualTextHint"
	return cursor_line,
		{
			virt_text = {
				{ " ● ", highlight },
				{ message .. " ", highlight },
			},
			virt_text_pos = "eol",
			hl_mode = "combine",
			priority = 2048,
			ephemeral = true,
		}
end

local function redraw(bufnr)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim__redraw({ buf = bufnr, valid = false })
	else
		vim.api.nvim__redraw({ valid = false })
	end
end

function M.refresh(bufnr)
	redraw(bufnr or vim.api.nvim_get_current_buf())
end

function M.is_enabled()
	return enabled
end

function M.toggle()
	enabled = not enabled
	redraw()
	return enabled
end

function M.setup()
	vim.api.nvim_set_decoration_provider(M.namespace, {
		on_win = function(_, winid, bufnr)
			local line, options = decoration_for_window(winid, bufnr)
			if line then
				vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line, 0, options)
			end
			return false
		end,
	})

	local group = vim.api.nvim_create_augroup("aakash-cursor-diagnostic", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "DiagnosticChanged", "CursorMoved", "CursorMovedI", "BufEnter", "WinEnter", "WinLeave" },
		{
			group = group,
			callback = function(event)
				M.refresh(event.buf)
			end,
		}
	)
	vim.keymap.set("n", "<leader>td", M.toggle, {
		desc = "[T]oggle cursor [D]iagnostic",
	})
	vim.schedule(redraw)
end

return M
