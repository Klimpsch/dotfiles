--[[
  Neovim config, based on kickstart.nvim (https://github.com/nvim-lua/kickstart.nvim)
  Plugins are managed with the built-in `vim.pack` (Neovim 0.12+).

  Quick reminders:
    :Tutor          Neovim basics
    :help           built-in docs (or <space>sh to fuzzy-search them)
    :checkhealth    diagnose install / plugin problems
    <space>R        reload this file
    Lua refresher:  https://learnxinyminutes.com/docs/lua/  and  :help lua-guide

  Layout:
     1. Options                    9. Treesitter
     2. Keymaps & autocmds        10. Statusline, buffers & focus
     3. Plugin manager (vim.pack) 11. Tools (git, terminal, explorer, outline)
     4. UI / core UX plugins      12. Markdown
     5. Search & navigation       13. Notes (obsidian.nvim)
     6. LSP                       14. Next steps
     7. Formatting                15. Terminal colours
     8. Autocomplete & snippets
--]]

-- ============================================================
-- SECTION 1: OPTIONS
-- Core Neovim settings, leaders, options
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  -- Set <space> as the leader key
  -- See `:help mapleader`
  --  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Set to true if you have a Nerd Font installed and selected in the terminal
  vim.g.have_nerd_font = false

  -- Use the terminal's own colour theme instead of a Neovim colorscheme.
  -- With this off, Neovim sends the terminal's 16 palette colours (and its
  -- default foreground/background) rather than 24-bit RGB values, so whatever
  -- theme your terminal is running is what you see. No colorscheme is loaded.
  -- Must be set before plugins load. See `:help 'termguicolors'`
  vim.o.termguicolors = false

  -- [[ Setting options ]]
  --  See `:help vim.o` and `:help option-list`

  -- Make line numbers default
  vim.o.number = true
  -- Relative line numbers help with jumping. Experiment to see if you like them.
  -- vim.o.relativenumber = true

  -- Enable mouse mode, can be useful for resizing splits for example!
  vim.o.mouse = 'a'

  -- Don't show the mode, since it's already in the status line
  vim.o.showmode = false

  -- Clipboard: NOT synced globally. Only yanks (y), pastes (p) and the
  -- explicit cut keys (Section 2) use the system clipboard, so ordinary
  -- deletes (d, x, c, s, <Del>) never overwrite it.
  --  See `:help 'clipboard'` and `:help registers`
  -- vim.o.clipboard = 'unnamedplus'

  -- Enable break indent
  vim.o.breakindent = true

  -- Enable undo/redo changes even after closing and reopening a file
  vim.o.undofile = true

  -- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- Keep signcolumn on by default
  vim.o.signcolumn = 'yes'

  -- Decrease update time
  vim.o.updatetime = 250

  -- Decrease mapped sequence wait time
  vim.o.timeoutlen = 300

  -- Configure how new splits should be opened
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- Sets how neovim will display certain whitespace characters in the editor.
  --  See `:help 'list'` and `:help 'listchars'`
  --
  --  listchars is set using `vim.opt` instead of `vim.o`, which offers a
  --  convenient interface for table-valued options. See `:help lua-options`
  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

  -- Preview substitutions live, as you type!
  vim.o.inccommand = 'split'

  -- Show which line your cursor is on
  vim.o.cursorline = true

  -- Minimal number of screen lines to keep above and below the cursor.
  vim.o.scrolloff = 10

  -- If an operation would fail due to unsaved changes (like `:q`),
  -- ask whether to save instead. See `:help 'confirm'`
  vim.o.confirm = true
end

-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- basic keymaps, basic autocmds
-- ============================================================
do
  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  -- Clear highlights on search when pressing <Esc> in normal mode
  --  See `:help hlsearch`
  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Disable `q` in normal mode (it starts macro recording, which is easy to hit
  -- by accident). Delete this line if you use macros. Plugin windows that use
  -- `q` to close map it buffer-locally, so they keep working.
  vim.keymap.set('n', 'q', '<Nop>')
  vim.keymap.set('n', '<leader>C', function() vim.cmd.edit(vim.env.MYVIMRC) end, { desc = 'Edit [C]onfig (init.lua)' })
  -- [[ Clipboard: copy, cut, paste ]]
  --  y / Y           copy to clipboard
  --  p / P           paste from clipboard
  --  <leader>d{motion}, <leader>dd, <leader>D   cut to clipboard
  --  visual c                                   cut selection to clipboard
  -- Everything else that deletes (d, x, c, s, <Del>) stays out of the clipboard.
  -- Deleted text is still in Neovim's own registers: `""p` pastes the last delete.
  -- If you type a register first (e.g. "ay or "ap), that register is used instead.
  do
    local function clip(keys)
      return function() return (vim.v.register == '"' and '"+' or '') .. keys end
    end
    local opts = { expr = true, silent = true }

    -- Copy
    vim.keymap.set({ 'n', 'x' }, 'y', clip 'y', vim.tbl_extend('force', opts, { desc = 'Copy to clipboard' }))
    vim.keymap.set('n', 'Y', clip 'y$', vim.tbl_extend('force', opts, { desc = 'Copy to end of line' }))

    -- Paste (visual P replaces the selection without copying what it replaced)
    vim.keymap.set('n', 'p', clip 'p', opts)
    vim.keymap.set('n', 'P', clip 'P', opts)
    vim.keymap.set('x', 'p', clip 'P', opts)
    vim.keymap.set('x', 'P', clip 'P', opts)

    -- Cut
    vim.keymap.set('n', '<leader>d', '"+d', { desc = 'Cut (motion) to clipboard' })
    vim.keymap.set('n', '<leader>D', '"+D', { desc = 'Cut to end of line' })
    -- Visual `c` cuts the selection. To replace a selection with typed text
    -- instead (what visual `c` normally does), use visual `s`.
    vim.keymap.set('x', 'c', '"+d', { desc = 'Cut selection to clipboard' })
  end

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- [[ Reload config ]]
  -- Re-sources init.lua without restarting Neovim. If you're editing init.lua
  -- and it has unsaved changes, it's written first so the reload picks them up.
  -- NOTE: Reloading re-runs every setup() call. That's fine for most tweaks
  --  (options, keymaps, plugin opts), but newly added plugins or big structural
  --  changes may still need a full restart.
  vim.keymap.set('n', '<leader>R', function()
    local config = vim.env.MYVIMRC
    local current = vim.api.nvim_buf_get_name(0)
    if vim.fn.resolve(current) == vim.fn.resolve(config) and vim.bo.modified then vim.cmd.write() end

    local ok, err = pcall(vim.cmd.source, config)
    if ok then
      vim.notify('Reloaded ' .. vim.fn.fnamemodify(config, ':~'), vim.log.levels.INFO)
    else
      vim.notify('Error reloading config:\n' .. err, vim.log.levels.ERROR)
    end
  end, { desc = '[R]eload init.lua' })

  -- Exit terminal mode in the builtin terminal with an easier shortcut than <C-\><C-n>.
  -- NOTE: This won't work in all terminal emulators/tmux/etc.
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- TIP: Disable arrow keys in normal mode
  -- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
  -- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
  -- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
  -- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

  -- Keybinds to make split navigation easier.
  --  Use CTRL+<hjkl> to switch between windows
  --  See `:help wincmd` for a list of all window commands
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
  -- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
  -- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
  -- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
  -- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  -- Highlight when yanking (copying) text
  --  Try it with `yap` in normal mode
  --  See `:help vim.hl.on_yank()`
  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })
end

-- ============================================================
-- SECTION 3: PLUGIN MANAGER
-- vim.pack intro, build hooks
-- ============================================================
do
  -- [[ Intro to `vim.pack` ]]
  -- `vim.pack` is the plugin manager built into Neovim.
  --
  --  See `:help vim.pack`, `:help vim.pack-examples` or the
  --  blog post from the creator of vim.pack and mini.nvim:
  --  https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack
  --
  --  Inspect plugin state and pending updates:
  --    :lua vim.pack.update(nil, { offline = true })
  --  Update plugins:
  --    :lua vim.pack.update()
  --
  --  The autocommand below runs build steps for certain plugins after they
  --  are installed or updated.

  local function run_build(name, cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd }):wait()
    if result.code ~= 0 then
      local stderr = result.stderr or ''
      local stdout = result.stdout or ''
      local output = stderr ~= '' and stderr or stdout
      if output == '' then output = 'No output from build command.' end
      vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
    end
  end

  -- See `:help vim.pack-events`
  vim.api.nvim_create_autocmd('PackChanged', {
    -- The augroup (with clear = true) stops this being registered twice when
    -- the config is reloaded with <leader>R.
    group = vim.api.nvim_create_augroup('kickstart-pack-build', { clear = true }),
    callback = function(ev)
      local name = ev.data.spec.name
      local kind = ev.data.kind
      if kind ~= 'install' and kind ~= 'update' then return end

      if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
        run_build(name, { 'make' }, ev.data.path)
        return
      end

      if name == 'LuaSnip' then
        if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
        return
      end

      if name == 'nvim-treesitter' then
        if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
        vim.cmd 'TSUpdate'
        return
      end

      -- markdown-preview.nvim needs its Node server built after install/update.
      -- Requires Node.js/npm on your PATH. Runs `yarn install` in the plugin's
      -- app/ folder via npx so you don't need yarn installed globally.
      if name == 'markdown-preview.nvim' then
        if vim.fn.executable 'npx' == 1 then
          run_build(name, { 'npx', '--yes', 'yarn', 'install' }, ev.data.path .. '/app')
        else
          vim.notify('markdown-preview.nvim: Node.js/npm not found on PATH; browser preview will not work.', vim.log.levels.WARN)
        end
        return
      end
    end,
  })
end

---Most plugins are hosted on GitHub; this helper saves some repetition.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================
-- SECTION 4: UI / CORE UX PLUGINS
-- guess-indent, gitsigns, which-key, colours, todo-comments, mini modules
-- ============================================================
do
  -- [[ Installing and Configuring Plugins ]]
  --
  -- To install a plugin, call `vim.pack.add` with its git url. This downloads
  -- the plugin's default branch (usually `main` or `master`).
  -- Most plugins also need their `.setup()` called to start them.

  -- Automatically detect and set indentation
  vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
  require('guess-indent').setup {}

  -- Git signs in the gutter, plus utilities for managing changes.
  -- See `:help gitsigns` to understand what each configuration key does.
  vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
  local gitsigns = require 'gitsigns'
  gitsigns.setup {
    signs = {
      add = { text = '+' }, ---@diagnostic disable-line: missing-fields
      change = { text = '~' }, ---@diagnostic disable-line: missing-fields
      delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
      topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
      changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
    },
    -- gitsigns.nvim's recommended keymaps:
    on_attach = function(bufnr)
      -- Navigation
      vim.keymap.set('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk 'next'
        end
      end, { desc = 'Jump to next git [c]hange', buf = bufnr })

      vim.keymap.set('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk 'prev'
        end
      end, { desc = 'Jump to previous git [c]hange', buf = bufnr })

      -- Visual mode actions
      vim.keymap.set('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [s]tage hunk', buf = bufnr })
      vim.keymap.set('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, { desc = 'git [r]eset hunk', buf = bufnr })
      -- Normal mode actions
      vim.keymap.set('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer', buf = bufnr })
      vim.keymap.set('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer', buf = bufnr })
      vim.keymap.set('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk', buf = bufnr })
      vim.keymap.set('n', '<leader>hi', gitsigns.preview_hunk_inline, { desc = 'git preview hunk [i]nline', buf = bufnr })
      vim.keymap.set('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'git [b]lame line', buf = bufnr })
      vim.keymap.set('n', '<leader>hd', gitsigns.diffthis, { desc = 'git [d]iff against index', buf = bufnr })
      vim.keymap.set('n', '<leader>hD', function() gitsigns.diffthis '~' end, { desc = 'git [D]iff against last commit', buf = bufnr })
      vim.keymap.set('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, { desc = 'git hunk [Q]uickfix list (all files in repo)', buf = bufnr })
      vim.keymap.set('n', '<leader>hq', gitsigns.setqflist, { desc = 'git hunk [q]uickfix list (all changes in this file)', buf = bufnr })
      -- Toggles
      vim.keymap.set('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line', buf = bufnr })
      vim.keymap.set('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = '[T]oggle git intra-line [w]ord diff', buf = bufnr })
      -- Text object
      vim.keymap.set({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = 'text object [i]nside [h]unk', buf = bufnr })
    end,
  }

  -- Useful plugin to show you pending keybinds.
  vim.pack.add { gh 'folke/which-key.nvim' }
  require('which-key').setup {
    -- Delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    icons = { mappings = vim.g.have_nerd_font },
    -- Document existing key chains
    spec = {
      { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>g', group = '[G]it' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      { '<leader>b', group = '[B]uffer' },
      { '<leader>m', group = '[M]arkdown' },
      { '<leader>n', group = '[N]otes (Obsidian)', mode = { 'n', 'v' } },
      { 'gr', group = 'LSP Actions', mode = { 'n' } },
    },
  }

  -- [[ Colours ]]
  -- No colorscheme: colours come from the terminal's theme (see 'termguicolors'
  -- in Section 1). A few small fix-ups for plugins live in Section 15.

  -- Highlight todo, notes, etc in comments
  vim.pack.add { gh 'folke/todo-comments.nvim' }
  require('todo-comments').setup { signs = false }

  -- [[ mini.nvim ]]
  --  A collection of various small independent plugins/modules
  --  NOTE: this bundles many `mini.*` modules (mini.ai, mini.surround,
  --  mini.statusline, mini.indentscope, mini.bufremove, ...). Do NOT also
  --  install any of those as a standalone repo elsewhere, or you'll end up
  --  with two copies of the same Lua module fighting on the runtimepath.
  vim.pack.add { gh 'nvim-mini/mini.nvim' }

  -- If a nerd font is available, load the icons module for pretty icons in various plugins.
  if vim.g.have_nerd_font then
    require('mini.icons').setup()
    -- Stands in for `nvim-web-devicons` for plugins that expect it (telescope, neo-tree, bufferline, ...)
    MiniIcons.mock_nvim_web_devicons()
  end

  -- Better Around/Inside textobjects
  --
  -- Examples:
  --  - va)  - [V]isually select [A]round [)]paren
  --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
  --  - ci'  - [C]hange [I]nside [']quote
  require('mini.ai').setup {
    -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
    mappings = {
      around_next = 'aa',
      inside_next = 'ii',
    },
    n_lines = 500,
  }

  -- Add/delete/replace surroundings (brackets, quotes, etc.)
  --
  -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
  -- - sd'   - [S]urround [D]elete [']quotes
  -- - sr)'  - [S]urround [R]eplace [)] [']
  require('mini.surround').setup()

  -- Animated indent-scope guide
  require('mini.indentscope').setup()

  -- NOTE: mini.statusline and mini.tabline are set up in Section 10.

  -- ... and there is more! Check out: https://github.com/nvim-mini/mini.nvim
end

-- ============================================================
-- SECTION 5: SEARCH & NAVIGATION
-- Telescope setup, keymaps, LSP picker mappings
-- ============================================================
do
  -- [[ Fuzzy Finder (files, lsp, etc) ]]
  --
  -- Telescope can fuzzy find files, help, keymaps, LSP symbols and much more.
  -- Try `:Telescope help_tags` to get a feel for it.
  --
  -- Inside any picker, press <c-/> (insert mode) or ? (normal mode) to see
  -- all of the keymaps available for that picker.

  -- NOTE: plenary.nvim is added here once; later plugins that need it
  --  (lazygit, neo-tree) rely on this.
  ---@type (string|vim.pack.Spec)[]
  local telescope_plugins = {
    gh 'nvim-lua/plenary.nvim',
    gh 'nvim-telescope/telescope.nvim',
    gh 'nvim-telescope/telescope-ui-select.nvim',
  }
  if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

  vim.pack.add(telescope_plugins)

  -- See `:help telescope` and `:help telescope.setup()`
  require('telescope').setup {
    -- You can put your default mappings / updates / etc. in here
    defaults = {
      mappings = {
        -- Ctrl-j / Ctrl-k move down / up the results while typing in the prompt.
        -- (<C-n>/<C-p> still work too.) In normal mode, plain j / k already work.
        i = {
          ['<C-j>'] = 'move_selection_next',
          ['<C-k>'] = 'move_selection_previous',
        },
      },
    },
    -- pickers = {}
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }

  -- Enable Telescope extensions if they are installed
  pcall(require('telescope').load_extension, 'fzf')
  pcall(require('telescope').load_extension, 'ui-select')

  -- See `:help telescope.builtin`
  local builtin = require 'telescope.builtin'
  vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
  vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
  vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

  -- Add Telescope-based LSP pickers when an LSP attaches to a buffer.
  -- If you later switch picker plugins, this is where to update these mappings.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
    callback = function(event)
      local buf = event.buf

      -- Find references for the word under your cursor.
      vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

      -- Jump to the implementation of the word under your cursor.
      vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

      -- Jump to the definition of the word under your cursor. Press <C-t> to jump back.
      vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

      -- Fuzzy find all the symbols (variables, functions, types, ...) in the current document.
      vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

      -- Fuzzy find all the symbols in your current workspace.
      vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

      -- Jump to the *type* of the word under your cursor (not where it was defined).
      vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
    end,
  })

  -- Fuzzy search in the current buffer, with a custom theme/layout
  vim.keymap.set('n', '<leader>/', function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  -- See `:help telescope.builtin.live_grep()` for the available options
  vim.keymap.set('n', '<leader>s/', function()
    builtin.live_grep {
      grep_open_files = true,
      prompt_title = 'Live Grep in Open Files',
    }
  end, { desc = '[S]earch [/] in Open Files' })

  -- Shortcut for searching your Neovim configuration files
  vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config', follow = true } end, { desc = '[S]earch [N]eovim files' })
end

-- ============================================================
-- SECTION 6: LSP
-- LSP keymaps, server configuration, Mason tools installations
-- ============================================================
do
  -- [[ LSP Configuration ]]
  -- LSP (Language Server Protocol) lets Neovim talk to external language
  -- servers (`gopls`, `lua_ls`, `rust_analyzer`, ...) for go-to-definition,
  -- references, completion, symbol search and more. The servers are separate
  -- programs; mason.nvim installs them for you.
  --
  -- LSP vs treesitter: see `:help lsp-vs-treesitter`

  -- Useful status updates for LSP.
  vim.pack.add { gh 'j-hui/fidget.nvim' }
  require('fidget').setup {}

  -- Runs every time an LSP attaches to a buffer, to set up buffer-local features.
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      -- Small helper so each mapping gets the buffer and an "LSP: " description prefix.
      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      -- Rename the variable under your cursor (usually across files too).
      map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

      -- Execute a code action; usually your cursor needs to be on an error or suggestion.
      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

      -- WARN: This is not Goto Definition, this is Goto Declaration.
      --  For example, in C this would take you to the header.
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      -- Highlight references of the word under your cursor when it rests there
      -- for a little while, and clear them when the cursor moves.
      --  See `:help CursorHold`
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })

        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      -- Toggle inlay hints, if the language server supports them
      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
    end,
  })

  -- Language servers to enable. Add/remove as you like; they're installed automatically.
  --  See `:help lsp-config` for information about keys and how to configure
  ---@type table<string, vim.lsp.Config>
  local servers = {
    -- clangd = {},
    -- gopls = {},
    -- pyright = {},
    -- tsc = {},
    --
    -- Some languages (like rust) have entire language plugins that can be useful:
    --    https://github.com/mrcjkb/rustaceanvim
    -- But for many setups, the LSP (`rust_analyzer`) will work just fine
    -- rust_analyzer = {},

    stylua = {}, -- Used to format Lua code

    -- Special Lua Config, as recommended by neovim help docs
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end

        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
            --  See https://github.com/neovim/nvim-lspconfig/issues/3189
            library = vim.api.nvim_get_runtime_file('', true),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false }, -- Disable formatting (formatting is done by stylua)
        },
      },
    },
  }

  vim.pack.add {
    gh 'neovim/nvim-lspconfig',
    gh 'mason-org/mason.nvim',
    gh 'mason-org/mason-lspconfig.nvim',
    gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  }

  -- Automatically install LSPs and related tools to stdpath for Neovim
  require('mason').setup {}

  -- Translates between nvim-lspconfig server names and mason.nvim package names (e.g. lua_ls <-> lua-language-server)
  require('mason-lspconfig').setup {
    automatic_enable = false, -- Change this to true if you want to automatically enable servers that are installed manually (e.g. via :Mason / :MasonInstall)
  }

  -- Ensure the servers and tools above are installed.
  --  Run `:Mason` to check status or install other tools (press `g?` for help there).
  local ensure_installed = vim.tbl_keys(servers)
  vim.list_extend(ensure_installed, {
    -- You can add other tools here that you want Mason to install
  })

  require('mason-tool-installer').setup { ensure_installed = ensure_installed }

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end
end

-- ============================================================
-- SECTION 7: FORMATTING
-- conform.nvim setup and keymap
-- ============================================================
do
  vim.pack.add { gh 'stevearc/conform.nvim' }
  require('conform').setup {
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- Filetypes to autoformat on save:
      local enabled_filetypes = {
        -- lua = true,
        -- python = true,
      }
      if enabled_filetypes[vim.bo[bufnr].filetype] then
        return { timeout_ms = 500 }
      else
        return nil
      end
    end,
    default_format_opts = {
      lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
    },
    formatters_by_ft = {
      -- rust = { 'rustfmt' },
      -- Conform can also run multiple formatters sequentially
      -- python = { "isort", "black" },
      --
      -- You can use 'stop_after_first' to run the first available formatter from the list
      -- javascript = { "prettierd", "prettier", stop_after_first = true },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
end

-- ============================================================
-- SECTION 8: AUTOCOMPLETE & SNIPPETS
-- blink.cmp and luasnip setup
-- ============================================================
do
  -- [[ Snippet Engine ]]

  -- NOTE: You can also pin a plugin to a version range of its git tags.
  --  See `:help vim.version.range()` for more info
  vim.pack.add { { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' } }
  require('luasnip').setup {}

  -- `friendly-snippets` contains a variety of premade snippets.
  --    https://github.com/rafamadriz/friendly-snippets
  --
  -- vim.pack.add { gh 'rafamadriz/friendly-snippets' }
  -- require('luasnip.loaders.from_vscode').lazy_load()

  -- [[ Autocomplete Engine ]]
  vim.pack.add { { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' } }
  require('blink.cmp').setup {
    keymap = {
      -- 'default' (recommended) for mappings similar to built-in completions
      --   <c-y> to accept ([y]es) the completion.
      --    This will auto-import if your LSP supports it.
      --    This will expand snippets if the LSP sent a snippet.
      -- 'super-tab' for tab to accept
      -- 'enter' for enter to accept
      -- 'none' for no mappings
      --
      -- For why 'default' is recommended, read `:help ins-completion`. Seriously, it's really good!
      --
      -- All presets have the following mappings:
      -- <tab>/<s-tab>: move to right/left of your snippet expansion
      -- <c-space>: Open menu or open docs if already open
      -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
      -- <c-e>: Hide menu
      -- <c-k>: Toggle signature help
      --
      -- See `:help blink-cmp-config-keymap` for defining your own keymap
      preset = 'default',

      -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
      --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = 'mono',
    },

    completion = {
      -- Press <c-space> to show documentation, or set `auto_show = true` to show it after a delay.
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      -- 'lsp' also covers obsidian.nvim's [[note]] and #tag completion (Section 13),
      -- since obsidian.nvim provides it through a built-in language server.
      default = { 'lsp', 'path', 'snippets' },
    },

    snippets = { preset = 'luasnip' },

    -- blink.cmp has an optional (recommended) Rust fuzzy matcher that downloads
    -- a prebuilt binary. We use the Lua implementation by default; switch to
    -- 'prefer_rust_with_warning' to try the Rust one.
    --  See `:help blink-cmp-config-fuzzy`
    fuzzy = { implementation = 'lua' },

    -- Shows a signature help window while you type arguments for a function
    signature = { enabled = true },
  }
end

-- ============================================================
-- SECTION 9: TREESITTER
-- Parser installation, syntax highlighting, folds, indentation
-- ============================================================
do
  -- [[ Configure Treesitter ]]
  --  Used to highlight, edit, and navigate code
  --  See `:help nvim-treesitter-intro`

  -- NOTE: You can also specify a branch or a specific commit
  vim.pack.add { { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' } }

  -- Ensure basic parsers are installed
  local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    -- Check if a parser exists and load it
    if not vim.treesitter.language.add(language) then return end

    -- Check if the buffer is valid (might not be after install completes)
    if not vim.api.nvim_buf_is_valid(buf) then return end

    -- Enable syntax highlighting and other treesitter features
    vim.treesitter.start(buf, language)

    -- Enable treesitter based folds (see `:help folds`)
    -- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    -- vim.wo.foldmethod = 'expr'

    -- Enable treesitter indentation if this language has an indent query;
    -- otherwise Vim's built-in indentexpr is used.
    -- `vim.bo[buf]` (not `vim.bo`) so it lands on the right buffer even when
    -- this runs later, after a parser finishes installing.
    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    -- Augroup prevents duplicate handlers when reloading with <leader>R.
    group = vim.api.nvim_create_augroup('kickstart-treesitter-attach', { clear = true }),
    callback = function(args)
      local buf, filetype = args.buf, args.match

      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

      if vim.tbl_contains(installed_parsers, language) then
        -- Enable the parser if it is already installed
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        -- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        -- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
        treesitter_try_attach(buf, language)
      end
    end,
  })
end

-- ============================================================
-- SECTION 10: STATUSLINE, BUFFERS & FOCUS
-- statusline, buffer tabs, buffer management, zen-mode + twilight
-- ============================================================
do
  -- [[ Statusline and buffer tabs ]]
  -- Both come from mini.nvim (Section 4). They build their colours from
  -- standard highlight groups, so they follow the terminal's theme.
  -- (lualine and bufferline were removed: lualine converts its colours to
  -- approximate 256-colour values instead of the terminal palette, and
  -- bufferline expects 'termguicolors' to be on.)
  local statusline = require 'mini.statusline'
  statusline.setup { use_icons = vim.g.have_nerd_font }
  ---@diagnostic disable-next-line: duplicate-set-field
  statusline.section_location = function() return '%2l:%-2v' end

  require('mini.tabline').setup { show_icons = vim.g.have_nerd_font }

  vim.keymap.set('n', '<S-l>', '<cmd>bnext<CR>', { desc = 'Next buffer' })
  vim.keymap.set('n', '<S-h>', '<cmd>bprevious<CR>', { desc = 'Prev buffer' })

  -- [[ Buffer management ]]
  -- mini.bufremove comes from mini.nvim (Section 4). Deleting buffers through
  -- it keeps your window layout intact.
  local function delete_buf(buf) require('mini.bufremove').delete(buf, false) end

  vim.keymap.set('n', '<leader>bn', '<cmd>enew<CR>', { desc = '[B]uffer [N]ew' })
  vim.keymap.set('n', '<leader>bd', function() delete_buf(0) end, { desc = '[B]uffer [D]elete' })
  vim.keymap.set('n', '<leader>bo', function()
    local cur = vim.api.nvim_get_current_buf()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if b ~= cur and vim.bo[b].buflisted then delete_buf(b) end
    end
  end, { desc = '[B]uffer delete [O]thers' })

  -- [[ Focus modes: zen-mode + twilight ]]
  vim.pack.add {
    gh 'folke/zen-mode.nvim',
    gh 'folke/twilight.nvim',
  }
  require('zen-mode').setup {
    -- Zen mode turns twilight on while it's open and off again when it closes,
    -- so twilight isn't left running globally (which dimmed Telescope popups).
    plugins = { twilight = { enabled = true } },
  }
  require('twilight').setup {
    -- Twilight asks treesitter for each window's parser on WinEnter. Popups and
    -- scratch buffers with no filetype have no parser, which crashes it
    -- ("attempt to index local 'parser' (a nil value)"), so exclude them.
    exclude = {
      '', -- no filetype (e.g. Telescope/ui-select popups)
      'TelescopePrompt',
      'TelescopeResults',
      'neo-tree',
      'aerial',
      'lazygit',
      'toggleterm',
      'help',
      'checkhealth',
      'qf',
    },
  }

  vim.keymap.set('n', '<leader>z', function()
    vim.ui.select({ 'Zen Mode', 'Twilight', 'Both' }, { prompt = 'Focus mode:' }, function(choice)
      if choice == 'Zen Mode' then
        -- One-off override so twilight stays off for this session
        require('zen-mode').toggle { plugins = { twilight = { enabled = false } } }
      elseif choice == 'Twilight' then
        vim.cmd 'Twilight'
      elseif choice == 'Both' then
        require('zen-mode').toggle() -- twilight comes along via the config above
      end
    end)
  end, { desc = '[Z]en / focus mode menu' })
end

-- ============================================================
-- SECTION 11: TOOLS
-- lazygit, toggleterm, neo-tree, aerial
-- ============================================================
do
  -- [[ LazyGit ]]
  -- Needs the `lazygit` binary on your PATH. (plenary.nvim is added in Section 5.)
  vim.pack.add { gh 'kdheepak/lazygit.nvim' }
  vim.keymap.set('n', '<leader>gg', '<cmd>LazyGit<CR>', { desc = 'Lazy[G]it' })

  -- [[ ToggleTerm ]]
  vim.pack.add { gh 'akinsho/toggleterm.nvim' }
  require('toggleterm').setup {
    open_mapping = [[<C-/>]], -- Ctrl-/ toggles the terminal
    direction = 'horizontal', -- opens at the bottom
    size = 15, -- height in rows
  }
  -- Some terminals send <C-_> for Ctrl-/, so catch that too
  vim.keymap.set({ 'n', 't' }, '<C-_>', '<cmd>ToggleTerm<CR>', { desc = 'Toggle terminal' })

  -- [[ Neo-tree file explorer ]]
  -- plenary.nvim is added in Section 5. File icons come from mini.icons
  -- (Section 4) when have_nerd_font is true, so nvim-web-devicons isn't needed.
  vim.pack.add {
    gh 'nvim-neo-tree/neo-tree.nvim',
    gh 'MunifTanjim/nui.nvim',
  }
  require('neo-tree').setup {}
  vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<CR>', { desc = 'File [E]xplorer' })

  -- [[ Aerial symbol outline ]]
  vim.pack.add { gh 'stevearc/aerial.nvim' }
  require('aerial').setup {}
  vim.keymap.set('n', '<leader>o', '<cmd>AerialToggle<CR>', { desc = 'Symbol [O]utline' })
end

-- ============================================================
-- SECTION 12: MARKDOWN
-- in-buffer rendering, browser preview
-- ============================================================
do
  -- [[ In-buffer rendering ]]
  -- Renders headings, code blocks, lists, tables, etc. directly in the buffer.
  -- Uses the `markdown` / `markdown_inline` parsers from Section 9.
  -- Inline `code` is shown as plain text (see RenderMarkdownCodeInline in Section 15).
  vim.pack.add { gh 'MeanderingProgrammer/render-markdown.nvim' }
  require('render-markdown').setup {
    enabled = false,
    -- Code block shading and borders need true colour; without it they show
    heading = { icons = { '' }, position = 'inline' },
    -- as reverse video and solid blocks, so turn them off (Section 1).
    code = {
      disable_background = true,
      border = 'none',
      language_border = ' ',
      -- With no background shading, indent code blocks so they stand
      -- apart from the surrounding text.
      left_margin = 2,
    },
  }
  vim.keymap.set('n', '<leader>mp', '<cmd>RenderMarkdown buf_toggle<CR>', { desc = '[M]arkdown [P]review (in-buffer) toggle' })

  -- render-markdown keeps a list of every buffer it has attached to and never
  -- removes closed ones (e.g. a Telescope preview of a .md file). After a
  -- <leader>R reload re-runs setup(), any command that loops over that list
  -- (`:RenderMarkdown`, `toggle`, `enable`, `disable`) hits a closed buffer and
  -- fails with "Invalid buffer id". Drop buffers from the list as they're wiped.
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = vim.api.nvim_create_augroup('render-markdown-prune', { clear = true }),
    callback = function(args)
      local buffers = require('render-markdown.core.manager').buffers
      for i = #buffers, 1, -1 do
        if buffers[i] == args.buf then table.remove(buffers, i) end
      end
    end,
  })

  -- [[ Browser preview ]]
  -- Opens a live-synced preview in your default browser. Requires Node.js/npm
  -- on your PATH; the Node server is built by the PackChanged autocmd in Section 3.
  -- Its options are read when the plugin loads, so set them before vim.pack.add.
  vim.g.mkdp_filetypes = { 'markdown' }
  -- vim.g.mkdp_auto_start = 1 -- auto-open the browser on entering a markdown file
  -- vim.g.mkdp_auto_close = 1 -- close the browser tab when leaving the markdown buffer
  vim.pack.add { gh 'iamcco/markdown-preview.nvim' }
  vim.keymap.set('n', '<leader>mb', '<cmd>MarkdownPreviewToggle<CR>', { desc = '[M]arkdown [B]rowser preview toggle' })
end

-- ============================================================
-- SECTION 13: NOTES (OBSIDIAN)
-- obsidian.nvim: journals, links, tags and backlinks in an Obsidian vault
-- ============================================================
do
  -- [[ obsidian.nvim ]]
  -- Works directly on an Obsidian vault (a plain folder of markdown files), so
  -- your notes stay compatible with the Obsidian app. Needs `ripgrep` on your PATH.
  --
  --  :Obsidian <Tab>        list subcommands
  --  :checkhealth obsidian  check the setup
  --
  -- Inside a note:
  --  <CR>        follow link / list notes with tag / toggle checkbox / fold heading
  --  [o  ]o      jump to previous / next link
  --  [[  #       autocomplete note links / tags (via blink.cmp, Section 8)
  --  [[^  [[^^   link to a block in this note / anywhere in the vault
  --  grr grn gra references / rename note / code actions (LSP keys, Sections 5-6)
  vim.pack.add { { src = gh 'obsidian-nvim/obsidian.nvim', version = vim.version.range '*' } }

  -- TODO: point this at your vault folder (used by the setup and <leader>nD below)
  local vault = vim.fs.normalize '~/vaults/notes'

  require('obsidian').setup {
    legacy_commands = false, -- this option goes away in obsidian.nvim 4.0
    workspaces = {
      { name = 'notes', path = vault },
    },
    daily_notes = {
      folder = 'journals', -- Logseq-style journal folder
      date_format = '%Y-%m-%d',
    },
    picker = { name = 'telescope.nvim' }, -- Telescope is set up in Section 5

    -- Name new notes after their title (e.g. "Project X.md"), like the Obsidian
    -- app and Logseq do. The default is a Zettelkasten-style timestamp ID with
    -- random letters (e.g. "1729112345-ABCD.md"), with the title as an alias.
    note_id_func = require('obsidian.builtin').title_id,
  }

  -- Concealing lets obsidian.nvim render links and checkboxes nicely.
  -- Set per markdown window so other filetypes (JSON etc.) aren't affected.
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('obsidian-conceal', { clear = true }),
    pattern = 'markdown',
    callback = function() vim.opt_local.conceallevel = 2 end,
  })

  -- [[ Keymaps ]] — all under <leader>n ("[N]otes" group in which-key, Section 4)
  local function map(mode, keys, cmd, desc) vim.keymap.set(mode, keys, cmd, { desc = desc }) end

  -- Journals
  map('n', '<leader>nj', '<cmd>Obsidian today<CR>', "Today's [J]ournal")
  map('n', '<leader>ny', '<cmd>Obsidian yesterday<CR>', "[Y]esterday's journal")
  map('n', '<leader>nd', '<cmd>Obsidian dailies -7 0<CR>', '[D]ailies (last 7 days)')

  -- Finding
  map('n', '<leader>nf', '<cmd>Obsidian quick_switch<CR>', '[F]ind note')
  map('n', '<leader>ns', '<cmd>Obsidian search<CR>', '[S]earch notes')
  map('n', '<leader>nt', '<cmd>Obsidian tags<CR>', '[T]ag index')
  map('n', '<leader>nb', '<cmd>Obsidian backlinks<CR>', '[B]acklinks')
  map('n', '<leader>nl', '<cmd>Obsidian links<CR>', '[L]inks in note')
  map('n', '<leader>nc', '<cmd>Obsidian toc<CR>', 'Table of [C]ontents')

  -- Creating
  map('n', '<leader>nn', '<cmd>Obsidian new<CR>', '[N]ew note')
  map('n', '<leader>nT', '<cmd>Obsidian new_from_template<CR>', 'New from [T]emplate')
  map('n', '<leader>no', '<cmd>Obsidian open<CR>', '[O]pen in Obsidian app')
  map('n', '<leader>np', function()
    vim.cmd.edit(vim.fn.fnameescape(vault .. '/Projects Dashboard.md'))
  end, '[P]roject dashboard')

  -- Deleting: removes the current note's file for good (no trash) and closes it.
  -- Asks first, and warns how many other notes link to it, since those links
  -- will break. Counts [[Note]], [[Note|alias]], [[Note#heading]] and
  -- [text](Note.md) style links, using ripgrep.
  map('n', '<leader>nD', function()
    local buf = vim.api.nvim_get_current_buf()
    local path = vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
    if path == '' or not vim.startswith(path, vault .. '/') or not path:match '%.md$' then
      vim.notify('Not a note in your vault: nothing deleted', vim.log.levels.WARN)
      return
    end

    -- Find other notes that link here
    local name = vim.fn.fnamemodify(path, ':t:r')
    local escaped = (name:gsub('[%.%^%$%*%+%?%(%)%[%]%{%}|\\]', '\\%0'))
    local pattern = '(\\[\\[|/)' .. escaped .. '(\\||#|\\]\\])|[(/]' .. escaped .. '\\.md[)#]'
    local count, checked = 0, false
    local ok, res = pcall(function() return vim.system({ 'rg', '--files-with-matches', '--glob', '*.md', '-e', pattern, vault }):wait() end)
    if ok and (res.code == 0 or res.code == 1) then
      checked = true
      for file in (res.stdout or ''):gmatch '[^\n]+' do
        if vim.fs.normalize(file) ~= path then count = count + 1 end
      end
    end

    local msg = ('Delete "%s" permanently?'):format(name)
    if not checked then
      msg = msg .. '\n(Could not check for links to it: is ripgrep installed?)'
    elseif count > 0 then
      msg = msg .. ('\n%d note%s to it; those links will break.'):format(count, count == 1 and ' links' or 's link')
    end
    if vim.fn.confirm(msg, '&Yes\n&No', 2) ~= 1 then return end

    if vim.fn.delete(path) ~= 0 then
      vim.notify('Could not delete ' .. path, vim.log.levels.ERROR)
      return
    end
    require('mini.bufremove').delete(buf, true) -- mini.nvim, Section 4
    vim.notify('Deleted ' .. name)
  end, '[D]elete note')

  -- Visual mode: select text first. These use `:` (not <cmd>) so the
  -- selected range is passed to the command.
  map('x', '<leader>nl', ':Obsidian link<CR>', '[L]ink selection to note')
  map('x', '<leader>nn', ':Obsidian link_new<CR>', 'Link selection to [N]ew note')
  map('x', '<leader>ne', ':Obsidian extract_note<CR>', '[E]xtract selection to new note')
end

-- ============================================================
-- SECTION 14: NEXT STEPS
-- kickstart example plugins, custom plugin modules
-- ============================================================
do
  -- These only work if you cloned the kickstart repo (not just copied init.lua).
  -- Uncomment to enable (restart nvim afterwards):
  --
  -- require 'kickstart.plugins.debug'
  -- require 'kickstart.plugins.lint'
  -- require 'kickstart.plugins.autopairs'
  -- require 'kickstart.plugins.indent_line' -- overlaps with mini.indentscope (Section 4)
  --
  -- (neo-tree is already set up directly in Section 11.)

  -- You can add your own plugins, configuration, etc. in `lua/custom/plugins/*.lua`.
  --
  -- For independent modules, uncomment the convenience loader:
  -- require 'custom.plugins'
  --
  -- `custom.plugins` loads files from that directory in an unspecified order.
  -- If plugins depend on each other, keep them in the same file with their
  -- `vim.pack.add()` and `setup()` calls in the required order, or require
  -- the modules explicitly in order:
  -- require 'custom.plugins.colorscheme'
  -- require 'custom.plugins.ui'
  -- require 'custom.plugins.git'
end

-- ============================================================
-- SECTION 15: TERMINAL COLOURS
-- Fix-ups so plugins use the terminal's palette (keep this last)
-- ============================================================
do
  -- With 'termguicolors' off (Section 1), Neovim uses your terminal's theme.
  -- Some plugins and default groups only define 24-bit colours, which are then
  -- ignored, so these give them terminal palette colours instead. Palette:
  --   1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, as set by your theme.
  --
  -- Only the six normal colours (1-6) are used. Many terminal themes make the
  -- "bright" colours (8-15) very dim or close to the background (Solarized,
  -- for example, uses them as background greys), which makes text vanish.
  -- This runs after every plugin is set up, so nothing overrides it.
  local function terminal_colours()
    local hl = function(name, val) vim.api.nvim_set_hl(0, name, val) end

    -- Swap any bright colour (8-15) for its normal version (0-7) in every
    -- highlight group defined so far, e.g. bright green 10 -> green 2.
    for name, def in pairs(vim.api.nvim_get_hl(0, {})) do
      if not def.link then
        local changed = false
        for _, key in ipairs { 'ctermfg', 'ctermbg' } do
          if def[key] and def[key] >= 8 and def[key] <= 15 then
            def[key] = def[key] - 8
            changed = true
          end
        end
        if changed then
          def.default = nil
          hl(name, def)
        end
      end
    end

    -- Comments, line numbers and whitespace markers in your normal text colour.
    -- Comments are italic so they still stand out. Set a colour here if you
    -- want them dimmer, e.g. { ctermfg = 8, italic = true } if 8 is readable.
    hl('Comment', { italic = true })
    hl('NonText', {})
    hl('LineNr', {})

    -- Twilight's "dimmed" text looks like a comment
    hl('Twilight', { link = 'Comment' })

    -- render-markdown inline `code` (Section 12): plain text, no colour or block.
    -- The second line clears treesitter's own highlight for code spans, which
    -- links to Comment (italic) by default and would otherwise show through.
    hl('RenderMarkdownCodeInline', {})
    hl('@markup.raw.markdown_inline', {})
    

    local heading_colours = { 4, 6, 2, 3, 5, 1 } -- #, ##, ###, ####, #####, ######
    for level, colour in ipairs(heading_colours) do
      hl('@markup.heading.' .. level .. '.markdown', { ctermfg = colour, bold = true })
      hl('RenderMarkdownH' .. level .. 'Bg', {})
    end

    -- todo-comments: TODO, FIX, NOTE, etc. in the terminal's red/yellow/cyan/...
    local todo = { FIX = 1, TODO = 6, HACK = 3, WARN = 3, PERF = 5, NOTE = 4, TEST = 5 }
    for kw, colour in pairs(todo) do
      hl('TodoFg' .. kw, { ctermfg = colour })
      hl('TodoBg' .. kw, { ctermfg = colour, reverse = true, bold = true })
    end

    -- Buffer tabs (mini.tabline, Section 10). Its default colours come out the
    -- same for every tab with this setup, so set them explicitly:
    --   current buffer   inverted block (your terminal's fg/bg swapped)
    --   shown in a split bold + underlined
    --   other buffers    plain text
    -- Unsaved changes turn the tab yellow (3).
    hl('MiniTablineCurrent', { reverse = true, bold = true })
    hl('MiniTablineVisible', { bold = true, underline = true })
    hl('MiniTablineHidden', {})
    hl('MiniTablineModifiedCurrent', { ctermfg = 3, reverse = true, bold = true })
    hl('MiniTablineModifiedVisible', { ctermfg = 3, bold = true, underline = true })
    hl('MiniTablineModifiedHidden', { ctermfg = 3 })
    hl('MiniTablineFill', {})
    hl('MiniTablineTabpagesection', { reverse = true })
  end

  terminal_colours()
  -- Re-apply once startup has finished (some plugins add highlight groups late)
  -- and whenever a colorscheme is loaded (that clears highlights).
  vim.api.nvim_create_autocmd({ 'VimEnter', 'ColorScheme' }, {
    group = vim.api.nvim_create_augroup('terminal-colours', { clear = true }),
    callback = terminal_colours,
  })
end
