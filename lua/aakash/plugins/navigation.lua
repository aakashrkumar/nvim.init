local project = require("aakash.project")

local function find_project_files()
	Snacks.picker.files({ cwd = project.get() })
end

local function open_project_picker()
	local function select_project(picker, item, new_tab)
		picker:close()
		if not item then
			return
		end

		vim.schedule(function()
			if new_tab then
				vim.cmd.tabnew()
			end
			if project.set(item.file, true) then
				find_project_files()
			end
		end)
	end

	Snacks.picker.projects({
		dev = { "~/Documents/Programming" },
		max_depth = 4,
		patterns = project.patterns,
		projects = { vim.fn.stdpath("config") },
		recent = true,
		transform = function(item)
			return not item.file:find("/_archive/", 1, true)
		end,
		confirm = function(picker, item)
			select_project(picker, item, false)
		end,
		actions = {
			project_tab = function(picker, item)
				select_project(picker, item, true)
			end,
		},
		win = {
			input = {
				keys = {
					["<c-t>"] = { "project_tab", mode = { "n", "i" } },
				},
			},
		},
	})
end

-- Snacks normally matches each document symbol by its own name. Add its
-- ancestors to the hidden match text so searching for a type such as `Hex`
-- also keeps that type's fields and methods in the result tree.
local function add_symbol_ancestors(item)
	local parent = item.parent
	while parent and not parent.root do
		if parent.name and parent.name ~= "" then
			item.text = item.text .. " " .. parent.name
		end
		parent = parent.parent
	end
	return item
end

return {
	-- [[ Split navigation across Neovim and tmux ]]
	{
		"mrjones2014/smart-splits.nvim",
		lazy = false,
		opts = {
			multiplexer_integration = "tmux",
		},
		config = function(_, opts)
			local smart_splits = require("smart-splits")
			smart_splits.setup(opts)

			vim.keymap.set("n", "<C-h>", smart_splits.move_cursor_left, { desc = "Move focus left" })
			vim.keymap.set("n", "<C-j>", smart_splits.move_cursor_down, { desc = "Move focus down" })
			vim.keymap.set("n", "<C-k>", smart_splits.move_cursor_up, { desc = "Move focus up" })
			vim.keymap.set("n", "<C-l>", smart_splits.move_cursor_right, { desc = "Move focus right" })
		end,
	},

	-- ============================================================
	-- SEARCH & NAVIGATION
	-- Snacks Picker keymaps and LSP navigation
	-- ============================================================
	{
		"folke/snacks.nvim",
		-- Snacks' visual services are configured in `ui.lua`. lazy.nvim merges
		-- this feature-local spec into that one, keeping navigation beside the
		-- workflows it implements without setting up the plugin twice.
		init = function()
			-- Add LSP pickers when a language server attaches. Buffer-local
			-- mappings only appear where their underlying LSP requests can work.
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("navigation-lsp-attach", { clear = true }),
				callback = function(event)
					local buf = event.buf
					local function map(keys, picker, desc)
						vim.keymap.set("n", keys, picker, { buffer = buf, desc = desc })
					end

					-- Find references for the word under your cursor.
					map("grr", Snacks.picker.lsp_references, "[G]oto [R]eferences")

					-- Find callers of the function under your cursor.
					map("grI", Snacks.picker.lsp_incoming_calls, "[G]oto [I]ncoming calls")

					-- Find functions called by the function under your cursor.
					map("grO", Snacks.picker.lsp_outgoing_calls, "[G]oto [O]utgoing calls")

					-- Jump to the implementation of the word under your cursor.
					-- Useful when a language can declare a type separately from its implementation.
					map("gri", Snacks.picker.lsp_implementations, "[G]oto [I]mplementation")

					-- Jump to the definition of the word under your cursor.
					-- To return to the previous location, press <C-t>.
					map("grd", Snacks.picker.lsp_definitions, "[G]oto [D]efinition")

					-- Fuzzy find symbols in the current document. Keeping the
					-- hierarchy makes fields and methods meaningful in large types.
					vim.keymap.set("n", "gO", function()
						Snacks.picker.lsp_symbols({
							tree = true,
							keep_parents = true,
							-- rust-analyzer represents `impl` blocks as Object symbols.
							-- Keep them so their methods retain the source hierarchy.
							filter = { rust = true },
							transform = add_symbol_ancestors,
						})
					end, { buffer = buf, desc = "Open Document Symbols" })

					-- Fuzzy find all symbols in the current language workspace.
					map("gW", Snacks.picker.lsp_workspace_symbols, "Open Workspace Symbols")

					-- Jump to the definition of the type under your cursor rather
					-- than to the declaration of the current value.
					map("grt", Snacks.picker.lsp_type_definitions, "[G]oto [T]ype Definition")
				end,
			})
		end,
		keys = {
			-- Snacks Picker can search files, text, editor state, Git, and LSP
			-- results through one interface. Press `?` inside a picker to see its
			-- actions. <Tab> selects entries; <C-q> sends them to quickfix, where
			-- <leader>q opens the persistent list through Quicker.
			{
				"<leader>sh",
				function()
					Snacks.picker.help()
				end,
				desc = "[S]earch [H]elp",
			},
			{
				"<leader>sk",
				function()
					Snacks.picker.keymaps()
				end,
				desc = "[S]earch [K]eymaps",
			},
			{ "<leader>sf", find_project_files, desc = "[S]earch [F]iles" },
			{
				"<leader>ss",
				function()
					Snacks.picker()
				end,
				desc = "[S]earch [S]elect picker",
			},
			{
				"<leader>sw",
				function()
					Snacks.picker.grep_word({ cwd = project.get() })
				end,
				mode = { "n", "v" },
				desc = "[S]earch current [W]ord",
			},
			{
				"<leader>sg",
				function()
					Snacks.picker.grep({ cwd = project.get() })
				end,
				desc = "[S]earch by [G]rep",
			},
			{
				"<leader>sd",
				function()
					Snacks.picker.diagnostics()
				end,
				desc = "[S]earch [D]iagnostics",
			},
			{
				"<leader>sN",
				function()
					Snacks.picker.notifications()
				end,
				desc = "[S]earch [N]otifications",
			},
			{
				"<leader>sr",
				function()
					Snacks.picker.resume()
				end,
				desc = "[S]earch [R]esume",
			},
			{
				"<leader>s.",
				function()
					Snacks.picker.recent()
				end,
				desc = '[S]earch Recent Files ("." for repeat)',
			},
			{
				"<leader>sc",
				function()
					Snacks.picker.commands()
				end,
				desc = "[S]earch [C]ommands",
			},
			{
				"<leader><leader>",
				function()
					Snacks.picker.smart({
						cwd = project.get(),
						filter = { cwd = true },
					})
				end,
				desc = "[ ] Smart find files",
			},
			{ "<leader>sp", open_project_picker, desc = "[S]earch [P]rojects" },
			{ "<leader>sP", project.use_current, desc = "[S]et current buffer [P]roject" },
			{
				"<leader>/",
				function()
					-- A compact list is enough when every result is already a
					-- line in the current buffer.
					Snacks.picker.lines({ layout = { preset = "vscode", preview = false } })
				end,
				desc = "[/] Fuzzily search in current buffer",
			},
			{
				"<leader>s/",
				function()
					Snacks.picker.grep_buffers()
				end,
				desc = "[S]earch [/] in Open Files",
			},
			{
				"<leader>sn",
				function()
					Snacks.picker.files({ cwd = vim.fn.stdpath("config"), follow = true })
				end,
				desc = "[S]earch [N]eovim files",
			},
		},
	},

	-- [[ Yank history ]]
	{
		"gbprod/yanky.nvim",
		dependencies = { "folke/snacks.nvim" },
		config = function()
			require("yanky").setup({
				-- ShaDa persists history across Neovim sessions without another dependency.
				ring = {
					storage = "shada",
				},

				-- Include text copied outside Neovim when running locally.
				-- Avoid clipboard synchronization over SSH.
				system_clipboard = {
					sync_with_ring = not vim.env.SSH_CONNECTION,
				},

				-- Match LazyVim's short highlight duration.
				highlight = {
					timer = 150,
				},
			})

			-- Yanky detects Snacks during setup and registers its picker source.
			-- Preserve normal yank/paste behavior while recording it in Yanky's history.
			vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)", {
				desc = "Yank text",
			})

			vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", {
				desc = "Put text after cursor",
			})

			vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", {
				desc = "Put text before cursor",
			})

			vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)", {
				desc = "Put text after cursor and move after it",
			})

			vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)", {
				desc = "Put text before cursor and move after it",
			})

			-- After pasting, cycle through older/newer yank-history entries.
			vim.keymap.set("n", "[y", "<Plug>(YankyCycleForward)", {
				desc = "Previous yank-history entry",
			})

			vim.keymap.set("n", "]y", "<Plug>(YankyCycleBackward)", {
				desc = "Next yank-history entry",
			})

			-- Browse and select from the complete history.
			vim.keymap.set({ "n", "x" }, "<leader>sy", function()
				Snacks.picker.yanky()
			end, {
				desc = "[S]earch [Y]ank history",
			})
		end,
	},

	-- [[ Harpoon 2 ]]
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")

			-- Required by Harpoon 2 to create its autocmds.
			local project = require("aakash.project")
			harpoon:setup({
				settings = {
					key = project.get,
				},
				default = {
					get_root_dir = project.get,
				},
			})

			-- Highlight and focus the current file when opening the Harpoon menu.
			harpoon:extend(require("harpoon.extensions").builtins.highlight_current_file())

			-- Add the current file to this project's Harpoon list.
			vim.keymap.set("n", "<leader>a", function()
				harpoon:list():add()
			end, {
				desc = "Harpoon: [A]dd current file",
			})

			-- Open Harpoon's editable list.
			vim.keymap.set("n", "<leader>p", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, {
				desc = "Harpoon: open [P]inned files",
			})

			-- Jump directly to Harpoon slots 1–4.
			for index = 1, 4 do
				local slot = index

				vim.keymap.set("n", "<leader>" .. slot, function()
					harpoon:list():select(slot)
				end, {
					desc = ("Harpoon: select file %d"):format(slot),
				})
			end

			-- Cycle through the Harpoon list, wrapping at either end.
			vim.keymap.set("n", "<leader>[", function()
				harpoon:list():prev({ ui_nav_wrap = true })
			end, {
				desc = "Harpoon: previous file",
			})

			vim.keymap.set("n", "<leader>]", function()
				harpoon:list():next({ ui_nav_wrap = true })
			end, {
				desc = "Harpoon: next file",
			})
		end,
	},

	{
		"folke/which-key.nvim",
		opts = function(_, opts)
			opts.spec = opts.spec or {}
			table.insert(opts.spec, { "<leader>s", group = "[S]earch", mode = { "n", "v" } })
		end,
	},

	-- [[ Search and replace ]]
	{
		"MagicDuck/grug-far.nvim",
		cmd = { "GrugFar", "GrugFarWithin" },
		opts = {},
		keys = {
			{
				"<leader>sR",
				function()
					require("grug-far").open({ prefills = { paths = require("aakash.project").get() } })
				end,
				desc = "[S]earch and [R]eplace",
			},
			{
				"<leader>sR",
				function()
					require("grug-far").with_visual_selection({ prefills = { paths = require("aakash.project").get() } })
				end,
				mode = "v",
				desc = "[S]earch and [R]eplace",
			},
		},
	},

	-- [[ Quickfix ]]
	{
		"stevearc/quicker.nvim",
		ft = "qf",
		opts = {
			keys = {
				{
					">",
					function()
						require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
					end,
					desc = "Expand quickfix context",
				},
				{
					"<",
					function()
						require("quicker").collapse()
					end,
					desc = "Collapse quickfix context",
				},
			},
		},
		keys = {
			{
				"<leader>q",
				function()
					require("quicker").toggle()
				end,
				desc = "[Q]uickfix",
			},
		},
	},

	-- [[ Enhanced jump motions ]]
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"<leader>j",
				function()
					require("flash").jump()
				end,
				mode = { "n", "x", "o" },
				desc = "Flash jump",
			},
			{
				"<leader>J",
				function()
					require("flash").treesitter()
				end,
				mode = { "n", "x", "o" },
				desc = "Flash Treesitter",
			},
			{
				"r",
				function()
					require("flash").remote()
				end,
				mode = "o",
				desc = "Remote Flash",
			},
			{
				"R",
				function()
					require("flash").treesitter_search()
				end,
				mode = { "o", "x" },
				desc = "Flash Treesitter search",
			},
			{
				"<C-s>",
				function()
					require("flash").toggle()
				end,
				mode = "c",
				desc = "Toggle Flash search",
			},
		},
	},
}
