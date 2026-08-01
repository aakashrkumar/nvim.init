--[[
=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- This configuration is split into small Lua modules so startup concerns and
-- plugin modules have clear homes. Lua's `require` loads each module once and
-- caches its return value; see `:help lua-guide-modules` and `:help require`.

-- [[ Setting options ]]
-- Leaders and editor options must be set before plugin specifications are loaded.
require 'options'

-- [[ Basic Keymaps ]]
-- These mappings use Neovim itself; mappings owned by plugins live beside those plugins.
require 'keymaps'

-- [[ Configure and install plugins ]]
require 'aakash.lazy'

-- [[ Optional examples / next steps ]]
-- The following comments only work if you have downloaded the repository, not
-- just copied this init.lua. The complete example specs are stored under
-- `lua/aakash/_examples/plugins/`.
--
-- NOTE: Next step on your Neovim journey: add/configure additional plugins.
--
-- Upstream Kickstart used `lua/kickstart/` for configuration maintained by the
-- template and `lua/custom/` as the user's extension point. This is now your
-- personal configuration: all active modules are deliberately owned together
-- under `aakash/`, so retaining that old ownership split would be misleading.
-- `_examples/` has a different purpose. It contains disabled learning material
-- and sits outside the imported `aakash.plugins` namespace so lazy.nvim cannot
-- enable an example simply because its file exists.
--
-- To try one, read its comments and move or adapt its returned spec into the
-- relevant feature module under `lua/aakash/plugins/`. Restart Neovim afterward
-- so lazy.nvim can install it and create any startup mappings or autocommands.
