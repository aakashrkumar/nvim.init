-- autopairs
-- https://github.com/windwp/nvim-autopairs

-- nvim-autopairs' official lazy.nvim example loads on the first InsertEnter.
-- `opts = {}` is equivalent to calling `require('nvim-autopairs').setup {}`.
return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },
}
