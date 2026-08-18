local writing_view = {
	content_width = 82,
	horizontal_padding = 3,
	horizontal_screen_margin = 1,
	min_framed_content_width = 60,
}

function writing_view.has_frame()
	local reserved_width = 2 * (writing_view.horizontal_padding + writing_view.horizontal_screen_margin + 1)

	return vim.o.columns >= writing_view.min_framed_content_width + reserved_width and vim.o.lines >= 3
end

function writing_view.width()
	if not writing_view.has_frame() then
		return math.max(1, vim.o.columns - 2 * writing_view.horizontal_screen_margin)
	end

	local reserved = 2 * (writing_view.horizontal_padding + writing_view.horizontal_screen_margin + 1)
	return math.min(writing_view.content_width, math.max(1, vim.o.columns - reserved))
end

function writing_view.height()
	return writing_view.has_frame() and math.max(1, vim.o.lines - 2) or vim.o.lines
end

function writing_view.canvas_width()
	return writing_view.width() + 2 * writing_view.horizontal_padding
end

function writing_view.canvas_height()
	return writing_view.height()
end

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
				transparent_background = true,
				float = {
					transparent = true,
				},
				lsp_styles = {
					inlay_hints = {
						background = false,
					},
				},
				custom_highlights = function(colors)
					return {
						MarkdownSelfNote = { fg = colors.overlay2, style = { "italic" } },
						WritingView = { bg = colors.base },
						WritingViewBorder = { fg = colors.surface0, bg = colors.base },
						WritingViewGutter = { bg = colors.base },
					}
				end,
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
		keys = {
			{
				"]w",
				function()
					Snacks.words.jump(vim.v.count1)
				end,
				mode = "n",
				desc = "Next word reference",
			},
			{
				"[w",
				function()
					Snacks.words.jump(-vim.v.count1)
				end,
				mode = "n",
				desc = "Previous word reference",
			},
		},
		opts = {
			-- Mostly invisible performance/robustness improvements.
			bigfile = { enabled = true },
			image = {
				enabled = true,
				doc = {
					auto_resize = true,
					-- Snacks anchors document images at their source column. Shift only
					-- block-math extmarks after rendering; inline math stays inline.
					on_update_pre = function(placement)
						local range = placement.opts.range
						if vim.bo[placement.buf].filetype ~= "markdown" or placement.opts.type ~= "math" or not range then return end

						local is_block = range[1] ~= range[3]
						if not is_block then
							local line = vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[1], false)[1] or ""
							is_block = line:sub(range[2] + 1, range[4]):sub(1, 2) == "$$"
						end
						if not is_block then return end

						vim.schedule(function()
							if not placement:ready() then return end
							local state = placement:state()
							if state.hidden or #state.wins == 0 then return end

							local width
							for _, win in ipairs(state.wins) do
								local info = vim.fn.getwininfo(win)[1]
								local text_width = info.width - info.textoff
								width = width and math.min(width, text_width) or text_width
							end

							local column = math.max(0, math.floor((width - state.loc.width) / 2))
							local padding = string.rep(" ", column)
							local namespace = Snacks.image.placement.ns
							for _, id in ipairs(placement.eids) do
								local mark = vim.api.nvim_buf_get_extmark_by_id(placement.buf, namespace, id, { details = true })
								local details = mark[3]
								local changed = false
								if details and details.virt_text then
									details.virt_text_win_col = column
									details.virt_text_pos = nil
									changed = true
								end
								if details and details.virt_lines then
									for _, virtual_line in ipairs(details.virt_lines) do
										if virtual_line[1] and virtual_line[1][2] == nil then
											virtual_line[1][1] = padding
										else
											table.insert(virtual_line, 1, { padding })
										end
									end
									changed = true
								end
								if changed then
									details.id = id
									details.ns_id = nil
									details.invalid = nil
									vim.api.nvim_buf_set_extmark(placement.buf, namespace, mark[1], mark[2], details)
								end
							end
						end)
					end,
				},
				resolve = function(file, src)
					local vault = vim.fs.root(file, ".obsidian")
					if not vault then return nil end
					local attachment = vim.fs.joinpath(vault, "700.Resources", "709.Attachments", src)
					return vim.uv.fs_stat(attachment) and attachment or nil
				end,
			},
			quickfile = { enabled = true },
			picker = { enabled = true },
			words = { enabled = true, modes = { "n" }, debounce = 300 },
			zen = {
				-- Match Obsidian's readable measure and turn the surrounding
				-- space into quiet gutters instead of an empty terminal.
				toggles = {
					dim = false,
					git_signs = false,
					mini_diff_signs = false,
				},
				show = {
					statusline = false,
					tabline = false,
				},
				on_open = function(win)
					if win.backdrop and win.backdrop:win_valid() then
						vim.api.nvim_set_option_value(
							"winhighlight",
							"Normal:WritingViewGutter,EndOfBuffer:WritingViewGutter",
							{ win = win.backdrop.win }
						)
					end

					local canvas

					local function close_canvas()
						if canvas then
							canvas:close()
							canvas = nil
						end
					end

					local function sync_canvas()
						if not win:valid() or not writing_view.has_frame() then
							close_canvas()
							return
						end

						if canvas and canvas:valid() then
							return
						end

						canvas = Snacks.win({
							enter = false,
							focusable = false,
							minimal = true,
							width = writing_view.canvas_width,
							height = writing_view.canvas_height,
							border = "rounded",
							backdrop = false,
							zindex = win.opts.zindex - 1,
							wo = {
								winhighlight = table.concat({
									"NormalFloat:WritingView",
									"FloatBorder:WritingViewBorder",
									"EndOfBuffer:WritingView",
								}, ","),
							},
						})
					end

					sync_canvas()
					win:on("WinClosed", close_canvas, { win = true })
					vim.api.nvim_create_autocmd("VimResized", {
						group = win.augroup,
						callback = function()
							vim.schedule(sync_canvas)
						end,
					})
				end,
				win = {
					width = writing_view.width,
					height = writing_view.height,
					backdrop = {
						transparent = false,
						blend = 0,
						win = { zindex = 38 },
					},
					wo = {
						winhighlight = "NormalFloat:WritingView,EndOfBuffer:WritingView",
						number = false,
						relativenumber = false,
						signcolumn = "no",
						list = false,
						cursorline = false,
						wrap = true,
						linebreak = true,
						breakindent = true,
					},
				},
			},
			-- Cleaner prompts and notifications.
			input = { enabled = true },
			notifier = {
				enabled = true,
				timeout = 3000,
			},
		},
	},
}
