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

local function first_non_empty_line(message)
	for line in tostring(message or ""):gmatch("[^\r\n]+") do
		line = trim(line)
		if line ~= "" then
			return line
		end
	end
	return ""
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

function M.format_message(diagnostic)
	local fallback = first_non_empty_line(diagnostic.message)
	local message = fallback
	message = message:gsub("%s+for further information visit%s+https?://%S+.*$", "")
	message = message:gsub("https?://%S+", "")
	message = message:gsub("%s+`#%[warn%b()%]`.*$", "")
	message = message:gsub("%s+#%[warn%b()%].*$", "")
	message = message:gsub("%s+%[[^%]]+%]%s*$", "")
	message = trim(message:gsub("%s+", " "))
	if message == "" then
		message = fallback
	end
	return truncate_display(message, max_message_width)
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

local function clear(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
	end
end

function M.refresh(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	clear(bufnr)

	if
		not enabled
		or not vim.api.nvim_buf_is_valid(bufnr)
		or vim.api.nvim_get_current_buf() ~= bufnr
		or not vim.diagnostic.is_enabled({ bufnr = bufnr })
	then
		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local diagnostic = M.select_diagnostic(vim.diagnostic.get(bufnr, { lnum = cursor_line }))
	if not diagnostic then
		return
	end

	local message = M.format_message(diagnostic)
	if message == "" then
		return
	end

	local highlight = severity_highlights[diagnostic.severity] or "DiagnosticVirtualTextHint"
	vim.api.nvim_buf_set_extmark(bufnr, M.namespace, cursor_line, 0, {
		virt_text = {
			{ " ● ", highlight },
			{ message .. " ", highlight },
		},
		virt_text_pos = "eol",
		hl_mode = "combine",
		priority = 2048,
	})
end

function M.is_enabled()
	return enabled
end

function M.toggle()
	enabled = not enabled
	if enabled then
		M.refresh()
	else
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			clear(bufnr)
		end
	end
	return enabled
end

function M.setup()
	local group = vim.api.nvim_create_augroup("aakash-cursor-diagnostic", { clear = true })
	vim.api.nvim_create_autocmd({ "DiagnosticChanged", "CursorMoved", "CursorMovedI", "BufEnter" }, {
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
