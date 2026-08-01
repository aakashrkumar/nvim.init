-- [[ Install and configure lazy.nvim ]]
--
-- lazy.nvim is a plugin manager written in Lua. A plugin manager downloads
-- plugins, adds them to Neovim's runtime, runs any required build steps, and
-- records versions so the same setup can be restored on another machine.
--
-- See the installation guide: https://lazy.folke.io/installation
-- See the plugin-spec reference: https://lazy.folke.io/spec

-- lazy.nvim cannot manage itself until Neovim can load it. On the first start,
-- clone its stable branch into Neovim's data directory. `stdpath('data')` keeps
-- downloaded plugins separate from this configuration; see `:help stdpath()`.
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local clone_output = vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    lazyrepo,
    lazypath,
  }

  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { clone_output, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- Prepending the directory to `runtimepath` makes lazy.nvim's Lua modules and
-- help files discoverable by `require` and `:help`; see `:help 'runtimepath'`.
vim.opt.runtimepath:prepend(lazypath)

-- Plugin modules return lazy.nvim "specs": Lua tables that name a repository
-- and describe its options, dependencies, build step, and loading conditions.
-- `opts` is normally passed to a plugin's `setup()` function automatically;
-- `init` runs during startup, while `config` runs after the plugin is loaded.
-- A `keys`, `cmd`, `event`, or `ft` field can intentionally defer loading until
-- that first use. Plugins stay eager unless their own documentation recommends
-- a safe trigger, so reorganizing the config does not become a loading contest.
--
-- Importing a module directory keeps the startup flow explicit without a long
-- ordered list of `require` calls. Every module below `aakash.plugins` is loaded
-- as configuration data. Disabled learning examples therefore live in
-- `aakash/_examples`, outside the imported namespace, and cannot turn on merely
-- because a new example file exists.
--
-- Useful commands:
--   :Lazy          inspect installed plugins and task output
--   :Lazy check    check whether updates are available
--   :Lazy update   update plugins and the lockfile
--   :Lazy restore  restore the versions recorded in lazy-lock.json
--   :Lazy log      inspect changes between plugin versions
--
-- `lazy-lock.json` should be kept in version control so another installation can
-- restore the same revisions. See https://lazy.folke.io/usage/lockfile.
require('lazy').setup {
  spec = {
    { import = 'aakash.plugins' },
  },
  install = { colorscheme = { 'catppuccin' } },

  -- lazy.nvim can install LuaRocks dependencies for plugins that ship a
  -- rockspec. None of this configuration's plugins require that package
  -- source, so disable it instead of provisioning a separate hererocks Lua.
  -- See `:help lazy.nvim-📦-packages-rockspec` and `:checkhealth lazy`.
  rocks = { enabled = false },
}
