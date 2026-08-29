local M = {}

-- Root detection follows the same LSP -> marker -> cwd model used by LazyVim
-- and AstroNvim. The active tab-local directory wins when a project was
-- selected explicitly.
M.patterns = {
	"Cargo.toml",
	"rust-project.json",
	"pyrightconfig.json",
	"pyproject.toml",
	"setup.py",
	"setup.cfg",
	"mvnw",
	"gradlew",
	"settings.gradle",
	"settings.gradle.kts",
	"pom.xml",
	"build.gradle",
	"build.gradle.kts",
	"build.xml",
	".clangd",
	"compile_commands.json",
	".luarc.json",
	".luarc.jsonc",
	"lua",
	".obsidian",
	".git",
}

local function normalize(path)
	if not path or path == "" then
		return nil
	end
	path = vim.fn.fnamemodify(path, ":p")
	return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local function contains(root, path)
	if root == path then
		return true
	end
	local prefix = root:sub(-1) == "/" and root or root .. "/"
	return path:sub(1, #prefix) == prefix
end

local function buffer_path(buf)
	return normalize(vim.api.nvim_buf_get_name(buf))
end

local function lsp_roots(buf, path)
	local roots = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
		if client.root_dir then
			roots[#roots + 1] = client.root_dir
		end
		for _, workspace in ipairs(client.workspace_folders or client.config.workspace_folders or {}) do
			roots[#roots + 1] = workspace.uri and vim.uri_to_fname(workspace.uri) or workspace.name
		end
	end

	local found = {}
	for _, root in ipairs(roots) do
		root = normalize(root)
		if root and contains(root, path) and not vim.tbl_contains(found, root) then
			found[#found + 1] = root
		end
	end
	table.sort(found, function(left, right)
		return #left > #right
	end)
	return found
end

function M.detect(buf)
	buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
	local path = buffer_path(buf)

	if path then
		local roots = lsp_roots(buf, path)
		if roots[1] then
			return roots[1], "lsp"
		end

		local marker = vim.fs.find(M.patterns, { path = path, upward = true })[1]
		if marker then
			return normalize(vim.fs.dirname(marker)), "marker"
		end

		local stat = vim.uv.fs_stat(path)
		return stat and stat.type == "directory" and path or vim.fs.dirname(path), "file"
	end

	return normalize(vim.fn.getcwd(-1, 0)), "cwd"
end

function M.get()
	if vim.fn.haslocaldir(-1, 0) == 1 then
		return normalize(vim.fn.getcwd(-1, 0))
	end
	local root = M.detect()
	return root
end

function M.set(path, notify)
	local root = normalize(path)
	local stat = root and vim.uv.fs_stat(root)
	if not stat or stat.type ~= "directory" then
		vim.notify(("Cannot use project root: %s"):format(path or ""), vim.log.levels.ERROR)
		return false
	end

	local ok, err = pcall(vim.fn.chdir, root, "tabpage")
	if not ok then
		vim.notify(("Cannot change project root to %s: %s"):format(root, err), vim.log.levels.ERROR)
		return false
	end
	if notify then
		vim.notify(("Project: %s"):format(root))
	end
	return true
end

function M.use_current()
	local root = M.detect()
	return M.set(root, true)
end

function M.info()
	if vim.fn.haslocaldir(-1, 0) == 1 then
		vim.notify(("Root: %s\nSource: tab"):format(M.get()))
		return
	end

	local root, source = M.detect()
	vim.notify(("Root: %s\nSource: %s"):format(root, source))
end

function M.setup()
	vim.api.nvim_create_user_command("ProjectRoot", function(command)
		if command.bang then
			M.use_current()
		elseif command.args ~= "" then
			M.set(command.args, true)
		else
			M.info()
		end
	end, { nargs = "?", bang = true, complete = "dir", desc = "Inspect or set the current tab project root" })
end

return M
