-- LaTeX authoring: VimTeX (the successor to the old vim-latex / LaTeX-Suite) plus a
-- LuaSnip port of Gilles Castel's math snippets.
--
-- Requires on the system (apt, per machine — not managed by lazy or Mason):
--   texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended
--   texlive-lang-german latexmk zathura zathura-pdf-poppler
--
-- Works unchanged on native Linux and under WSLg, which is why zathura is the viewer.

---@module 'lazy'
---@type LazySpec
return {
  {
    'lervag/vimtex',
    lazy = false, -- VimTeX must load before the first tex buffer; do not lazy-load on ft.
    -- Unpinned: tracks VimTeX master, which requires neovim >= 0.12.4. Both machines are
    -- standardised on the upstream 0.12.4 tarball, and kickstart/health.lua asserts that
    -- floor — so `:checkhealth kickstart` is the first thing to check if VimTeX refuses
    -- to load with "does not support your version of Vim".
    init = function()
      -- Compiler: latexmk in continuous mode, so the PDF refreshes as you save.
      vim.g.vimtex_compiler_method = 'latexmk'
      vim.g.vimtex_compiler_latexmk = {
        aux_dir = 'build',
        out_dir = 'build',
        continuous = 1,
        options = {
          '-shell-escape',
          '-verbose',
          '-file-line-error',
          '-synctex=1',
          '-interaction=nonstopmode',
        },
      }

      -- Viewer: zathura speaks SyncTeX in both directions.
      --   forward search  = <leader>lv          (nvim -> pdf)
      --   inverse search  = <C-LeftMouse>       (pdf -> nvim)
      vim.g.vimtex_view_method = 'zathura'

      -- Conceal: render \alpha as α, hide $ and superfluous braces, but only on lines
      -- the cursor is not on, so editing still shows the real source.
      vim.g.vimtex_syntax_conceal = {
        accents = 1,
        greek = 1,
        math_bounds = 1,
        math_delimiters = 1,
        math_super_sub = 1,
        math_symbols = 1,
        sections = 0,
        styles = 1,
      }

      -- Quickfix: don't hijack the window for warnings you can't act on.
      vim.g.vimtex_quickfix_open_on_warning = 0
      vim.g.vimtex_quickfix_ignore_filters = {
        'Underfull \\\\hbox',
        'Overfull \\\\hbox',
        'LaTeX Warning: .\\+ float specifier changed to',
        'Package hyperref Warning: Token not allowed in a PDF string',
      }

      -- Table of contents behaves like the old LaTeX-Suite \lt.
      vim.g.vimtex_toc_config = {
        name = 'TOC',
        layers = { 'content', 'todo', 'include' },
        split_width = 40,
        todo_sorted = 0,
        show_help = 1,
        show_numbers = 1,
      }

      -- Don't open the fold-under-cursor automatically; folds off by default.
      vim.g.vimtex_fold_enabled = 0
    end,
    config = function()
      -- VimTeX ships its own syntax engine with much better conceal support than the
      -- treesitter latex parser, and the two fight over highlighting. The parser is
      -- deliberately absent from the treesitter parser list in init.lua; this guards
      -- against it being installed later as a dependency of another parser.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('vimtex-no-treesitter', { clear = true }),
        pattern = { 'tex', 'plaintex' },
        callback = function(args)
          pcall(vim.treesitter.stop, args.buf)
          vim.wo.conceallevel = 2

          -- Label the <localleader>l prefix in which-key, buffer-locally so it doesn't
          -- appear in non-LaTeX buffers. (`ft` is not a valid which-key spec field —
          -- only group/desc/icon/buffer/mode/cond are.)
          local ok, wk = pcall(require, 'which-key')
          if ok then wk.add { { '<localleader>l', group = '[L]aTeX (VimTeX)', buffer = args.buf } } end
        end,
      })
    end,
    -- No `keys` block on purpose: VimTeX already installs its own buffer-local
    -- <localleader>l… mappings (ll compile, lv view, lt toc, le errors, lk kill, lc clean),
    -- which are exactly the LaTeX-Suite bindings. Since init.lua sets maplocalleader to
    -- <space>, they read as <space>ll, <space>lv, … here. See :h vimtex-default-mappings.
  },

  {
    -- Gilles Castel's "write LaTeX as fast as you can write it by hand" snippets,
    -- ported to LuaSnip. Uses VimTeX to detect math zones, so `ff` -> \frac{}{}
    -- expands inside $...$ but not in prose.
    'iurimateus/luasnip-latex-snippets.nvim',
    ft = { 'tex', 'plaintex', 'markdown' },
    dependencies = { 'L3MON4D3/LuaSnip', 'lervag/vimtex' },
    config = function()
      require('luasnip-latex-snippets').setup { use_treesitter = false }
      require('luasnip').config.setup { enable_autosnippets = true }
    end,
  },
}
