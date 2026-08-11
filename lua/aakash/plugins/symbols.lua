local symbol_kinds = {
	"Module",
	"Namespace",
	"Package",
	"Class",
	"Method",
	"Property",
	"Field",
	"Constructor",
	"Enum",
	"Interface",
	"Function",
	"Variable",
	"Constant",
	"Struct",
	"Object",
	"EnumMember",
	"Trait",
	"TypeParameter",
}

return {
	{
		"Bekaboo/dropbar.nvim",
		lazy = false,
		config = function()
			vim.keymap.set("n", "<leader>;", require("dropbar.api").pick, { desc = "Pick dropbar context" })
			vim.keymap.set("n", "[;", require("dropbar.api").goto_context_start, { desc = "Go to context start" })
			vim.keymap.set("n", "];", require("dropbar.api").select_next_context, { desc = "Select next context" })
		end,
	},

	-- A transient outline for browsing the current buffer as a hierarchy.
	{
		"stevearc/aerial.nvim",
		cmd = "AerialToggle",
		keys = {
			{
				"<leader>to",
				"<cmd>AerialToggle right<CR>",
				desc = "[T]oggle symbol outline (right)",
			},
			{
				"<leader>tO",
				"<cmd>AerialToggle float<CR>",
				desc = "[T]oggle symbol outline (float)",
			},
		},
		opts = {
			-- rust-analyzer exposes fields that Aerial's Rust Tree-sitter query does
			-- not, so prefer LSP there and keep Tree-sitter as the fallback.
			backends = {
				rust = { "lsp", "treesitter" },
				["_"] = { "treesitter", "lsp", "markdown", "asciidoc", "man" },
			},
			filter_kind = false,
			close_on_select = false,
			keymaps = {
				q = "actions.close",
				["<Esc>"] = "actions.close",
			},
		},
	},

	-- Namu's compact, source-ordered symbol navigator complements the richer
	-- Snacks picker without replacing the `gO` workflow.
	{
		"bassamsdata/namu.nvim",
		cmd = "Namu",
		keys = {
			{
				"<leader>so",
				"<cmd>Namu symbols<CR>",
				desc = "[S]earch buffer symbols (Namu)",
			},
		},
		opts = {
			namu_symbols = {
				options = {
					AllowKinds = {
						default = symbol_kinds,
						rust = symbol_kinds,
						java = symbol_kinds,
						python = symbol_kinds,
						c = symbol_kinds,
						cpp = symbol_kinds,
					},
					display = {
						format = "tree_guides",
					},
				},
			},
		},
	},
}
