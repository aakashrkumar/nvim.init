return {
	-- Useful plugin to show you pending keybinds.
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		-- Group fragments live beside the features they describe. Preserve every
		-- `spec` entry when lazy.nvim merges those repeated plugin specifications.
		opts_extend = { "spec" },
		opts = {
			-- Delay between pressing a key and opening which-key (milliseconds)
			delay = 0,
			icons = { mappings = vim.g.have_nerd_font },
			-- Document existing key chains
			spec = {
				{ "<leader>t", group = "[T]oggle" },
			},
		},
	},

	-- [[ Colorscheme ]]
	-- You can easily change to a different colorscheme.
	-- Change the name of the colorscheme plugin below, and then
	-- change the command under that to load whatever the name of that colorscheme is.
	--
	-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
	-- {
	--   'folke/tokyonight.nvim',
	--   opts = {
	--     styles = {
	--       comments = { italic = false }, -- Disable italics in comments
	--     },
	--   },
	-- }
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				lsp_styles = {
					inlay_hints = {
						background = false,
					},
				},
			})
			-- Load the colorscheme here.
			-- Like many other themes, this one has different styles, and you could load
			-- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
			vim.cmd.colorscheme("catppuccin-mocha")
		end,
	},

	{
		"sphamba/smear-cursor.nvim",
		opts = {
			stiffness = 0.8,
			trailing_stiffness = 0.5,
			distance_stop_animating = 0.5,
		},
	},

	-- Snacks
	-- Snacks' official lazy.nvim example keeps the plugin eager because some of
	-- its small UI services are designed to be available during startup.
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		opts = {
			-- Mostly invisible performance/robustness improvements.
			bigfile = { enabled = true },
			quickfile = { enabled = true },
			picker = { enabled = true },
			-- Cleaner prompts and notifications.
			input = { enabled = true },
			notifier = {
				enabled = true,
				timeout = 3000,
			},
		},
	},
}
