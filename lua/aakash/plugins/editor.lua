return {
	-- [[ Installing and Configuring Plugins ]]
	--
	-- lazy.nvim plugin specifications are Lua tables. The first value identifies
	-- the GitHub repository; other keys describe configuration and loading.
	--
	-- For most plugins it is not enough to install them: their `setup()` function
	-- must also run. lazy.nvim's `opts` field calls that setup function with the
	-- table you provide. Use `config` when setup requires additional Lua logic.
	--
	-- For example, lets say we want to install `guess-indent.nvim` - a plugin for
	-- automatically detecting and setting the indentation.
	--
	-- We first install it from https://github.com/NMAC427/guess-indent.nvim
	-- and then call its `setup()` function to start it with default settings.
	{
		"NMAC427/guess-indent.nvim",
		opts = {},
	},

	-- Highlight todo-style comments and search them through Snacks Picker.
	{
		"folke/todo-comments.nvim",
		-- `keys` would normally make this plugin lazy. Keep highlighting active
		-- immediately and use the mappings only as picker entry points.
		lazy = false,
		dependencies = {
			"folke/snacks.nvim",
			"nvim-lua/plenary.nvim",
		},
		keys = {
			{
				"<leader>st",
				function()
					Snacks.picker.todo_comments()
				end,
				desc = "[S]earch [T]odo comments",
			},
			{
				"<leader>sT",
				function()
					Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } })
				end,
				desc = "[S]earch [T]odo/Fix/Fixme",
			},
		},
		opts = { signs = false },
	},

	-- treesitter text objets
	{
		"nvim-mini/mini.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
		config = function()
			-- [[ mini.nvim ]]
			local project = require("aakash.project")

			--  A collection of various small independent plugins/modules

			-- If a nerd font is available, load the icons module for pretty icons in various plugins.
			if vim.g.have_nerd_font then
				require("mini.icons").setup()
				-- Expose MiniIcons through the compatibility API for plugins that still expect `nvim-web-devicons`.
				MiniIcons.mock_nvim_web_devicons()
			end

			-- Better Around/Inside textobjects
			--
			-- Examples:
			--  - va)  - [V]isually select [A]round [)]paren
			--  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
			--  - ci'  - [C]hange [I]nside [']quote

			local ai = require("mini.ai")
			require("mini.ai").setup({
				-- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
				mappings = {
					around_next = "aa",
					inside_next = "ii",
				},
				n_lines = 500,
				custom_textobjects = {
					o = ai.gen_spec.treesitter({
						a = {
							"@block.outer",
							"@conditional.outer",
							"@loop.outer",
						},
						i = {
							"@block.inner",
							"@conditional.inner",
							"@loop.inner",
						},
					}),

					-- Around/inside a function definition.
					f = ai.gen_spec.treesitter({
						a = "@function.outer",
						i = "@function.inner",
					}),

					-- Around/inside a class, struct, impl, or equivalent language construct.
					c = ai.gen_spec.treesitter({
						a = "@class.outer",
						i = "@class.inner",
					}),

					-- Mini.ai normally uses `f` for a function call. Since `f` now means
					-- function definition, preserve function-call text objects under `u`,
					-- matching LazyVim's convention: "usage".
					u = ai.gen_spec.function_call(),

					-- Function call without including a dotted receiver.
					U = ai.gen_spec.function_call({
						name_pattern = "[%w_]",
					}),
				},
			})

			-- Add/delete/replace surroundings (brackets, quotes, etc.)
			--
			-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
			-- - sd'   - [S]urround [D]elete [']quotes
			-- - sr)'  - [S]urround [R]eplace [)] [']
			require("mini.surround").setup()

			-- Simple and easy statusline.
			--  You could remove this setup call if you don't like it,
			--  and try some other statusline plugin
			local statusline = require("mini.statusline")
			-- Set `use_icons` to true if you have a Nerd Font
			statusline.setup({ use_icons = vim.g.have_nerd_font })

			-- You can configure sections in the statusline by overriding their
			-- default behavior. For example, here we set the section for
			-- cursor location to LINE:COLUMN
			---@diagnostic disable-next-line: duplicate-set-field
			statusline.section_location = function()
				return "%2l:%-2v"
			end

			require("mini.files").setup({
				windows = { preview = true, width_preview = 40 },
				options = { permanent_delete = false },
			})

			vim.api.nvim_create_autocmd("User", {
				group = vim.api.nvim_create_augroup("minifiles-lsp-rename", { clear = true }),
				pattern = "MiniFilesActionRename",
				desc = "Notify LSP clients after MiniFiles renames",
				callback = function(event)
					Snacks.rename.on_rename_file(event.data.from, event.data.to)
				end,
			})

			vim.keymap.set("n", "-", function()
				local file = vim.api.nvim_buf_get_name(0)
				MiniFiles.open(file ~= "" and file or nil)
			end, { desc = "File explorer (at current file)" })

			vim.keymap.set("n", "<leader>e", function()
				MiniFiles.open(project.get())
			end, { desc = "File [E]xplorer (project root)" })

			require("mini.pairs").setup()
			require("mini.bracketed").setup({
				-- Keep existing word-reference and persistent yank-history navigation.
				window = { suffix = "" },
				yank = { suffix = "" },
			})
			require("mini.splitjoin").setup()
			require("mini.align").setup()

			local visits = require("mini.visits")
			visits.setup()
			vim.keymap.set("n", "<leader>sv", function()
				visits.select_path(project.get())
			end, { desc = "[S]earch [V]isited files" })
			-- ... and there is more!
			--  Check out: https://github.com/nvim-mini/mini.nvim
		end,
	},

	{
		"monaqa/dial.nvim",
		config = function()
			local dial_map = require("dial.map")
			vim.keymap.set("n", "<C-a>", function()
				dial_map.manipulate("increment", "normal")
			end)
			vim.keymap.set("n", "<C-x>", function()
				dial_map.manipulate("decrement", "normal")
			end)
			vim.keymap.set("n", "g<C-a>", function()
				dial_map.manipulate("increment", "gnormal")
			end)
			vim.keymap.set("n", "g<C-x>", function()
				dial_map.manipulate("decrement", "gnormal")
			end)
			vim.keymap.set("x", "<C-a>", function()
				dial_map.manipulate("increment", "visual")
			end)
			vim.keymap.set("x", "<C-x>", function()
				dial_map.manipulate("decrement", "visual")
			end)
			vim.keymap.set("x", "g<C-a>", function()
				dial_map.manipulate("increment", "gvisual")
			end)
			vim.keymap.set("x", "g<C-x>", function()
				dial_map.manipulate("decrement", "gvisual")
			end)
		end,
	},

	-- [[ Undo history visualizer ]]
	{
		"mbbill/undotree",
		cmd = "UndotreeToggle",
		init = function()
			vim.g.undotree_WindowLayout = 3
			vim.g.undotree_SetFocusWhenToggle = 1
			vim.g.undotree_ShortIndicators = 1
		end,
		keys = {
			{
				"<leader>u",
				"<cmd>UndotreeToggle<CR>",
				silent = true,
				desc = "Toggle [U]ndo tree",
			},
		},
	},

	{
		"ThePrimeagen/vim-be-good",
		cmd = "VimBeGood",
	},
}
