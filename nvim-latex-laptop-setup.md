# Laptop setup: Neovim + LaTeX (kickstart config)

Instructions for an agent running on the **private Ubuntu laptop**. The goal is to bring
that machine to the same state as the WSL2 work machine: upstream Neovim 0.12.4, the shared
kickstart config pulled from git, and a working LaTeX toolchain.

The Neovim config itself is **already done and pushed** — do not modify it. This is purely
host-side setup plus one `git pull`.

Config repo: `git@github.com:DrDonkeyKong/kickstart.nvim.git` → `~/.config/nvim`

---

## Context: what was set up on the other machine

- **VimTeX** (`lervag/vimtex`, master) as the LaTeX plugin, replacing the old vim-latex /
  LaTeX-Suite the user knew from university.
- **`iurimateus/luasnip-latex-snippets.nvim`** — a LuaSnip port of Gilles Castel's math
  snippets (149 auto-snippets for `tex`). Uses VimTeX for math-zone detection.
- **texlab** LSP and **latexindent** formatter, both auto-installed by Mason on first launch.
- Treesitter is deliberately **disabled for `tex`** — VimTeX's own syntax engine has better
  `conceal` support and the two conflict. Do not add a `latex` parser.
- Compilation is `latexmk` in continuous mode, output into a `build/` subdirectory.
- PDF viewer is **zathura**, chosen because it works identically on native Linux and under
  WSLg, with SyncTeX in both directions.

---

## Prerequisite check

Report these before changing anything:

```bash
nvim --version | head -1
command -v nvim
lsb_release -ds
ls -d ~/.config/nvim 2>/dev/null && git -C ~/.config/nvim remote -v
apt-cache policy neovim | head -3
```

Two things matter:

1. **Neovim must end up at >= 0.12.4.** VimTeX master requires it. Anything older and
   VimTeX aborts with `Error: VimTeX does not support your version of Vim`.
2. **Where the current `nvim` comes from.** If it is from `ppa:neovim-ppa/unstable`, note
   that this PPA is abandoned — its Ubuntu noble index has published nothing since
   2026-01-11 and it only ever offered a pre-0.12.0 dev snapshot. Do not try to
   `apt upgrade` out of it; it will not work.

---

## Step 1 — Neovim 0.12.4 from the upstream tarball

Skip this step only if `nvim --version` already reports >= 0.12.4 **and** it is not a
distro/PPA package (check `dpkg -S $(command -v nvim)` returns nothing).

```bash
cd /tmp
curl -fLO https://github.com/neovim/neovim/releases/download/v0.12.4/nvim-linux-x86_64.tar.gz
tar -xzf nvim-linux-x86_64.tar.gz -C ~/.local/share
mkdir -p ~/.local/bin
ln -sf ~/.local/share/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim
```

Then confirm `~/.local/bin` precedes `/usr/bin` in `PATH`:

```bash
echo "$PATH" | tr ':' '\n' | grep -nE '^(/home/[^/]+/.local/bin|/usr/bin)$'
command -v nvim && nvim --version | head -2
```

If `~/.local/bin` is missing from `PATH` or comes after `/usr/bin`, prepend it in
`~/.bashrc` (or `~/.zshrc`) and re-open the shell. Do **not** skip this — the symlink is
what shadows any distro build.

Expected: `NVIM v0.12.4`.

**To undo at any point:** `rm ~/.local/bin/nvim`. Nothing is overwritten.

Then, only if the old Neovim came from the dead PPA:

```bash
sudo apt purge neovim
sudo add-apt-repository -r ppa:neovim-ppa/unstable
```

This is cosmetic — the symlink already wins on `PATH`. It just stops the dead source
appearing in `apt upgrade`.

## Step 2 — LaTeX toolchain

```bash
sudo apt install texlive-latex-recommended texlive-latex-extra \
     texlive-fonts-recommended texlive-lang-german latexmk \
     zathura zathura-pdf-poppler \
     libyaml-tiny-perl liblog-log4perl-perl libfile-homedir-perl
```

Roughly 1.5 GB, versus ~5.5 GB for `texlive-full`.

- The three `perl` packages are dependencies of `latexindent` (the formatter bound to
  `<space>f`). Without them it fails silently.
- Add `texlive-science` if `siunitx` / `physics` are needed.
- Add `texlive-bibtex-extra` and `biber` for biblatex bibliographies.

Verify:

```bash
latexmk --version && zathura --version && which latexindent
```

## Step 3 — Pull the config

```bash
git -C ~/.config/nvim pull
```

If `~/.config/nvim` does not exist yet:

```bash
git clone git@github.com:DrDonkeyKong/kickstart.nvim.git ~/.config/nvim
```

The repo tracks `lazy-lock.json`, so lazy.nvim installs every plugin at the exact commit
the other machine uses. Do not run `:Lazy update` or `:Lazy sync` — that defeats the
pinning and will produce a lockfile diff. If plugins need installing, `:Lazy restore` is
the correct command.

## Step 4 — First launch

```bash
nvim --headless "+Lazy! restore" +qa
```

Then open Neovim normally once and let Mason finish installing `texlab` and `latexindent`
(watch the bottom-right notifications; it takes a minute). Confirm:

```bash
ls ~/.local/share/nvim/mason/bin/
```

Expect `texlab` and `latexindent` present.

## Step 5 — Verify

```bash
nvim -c 'checkhealth kickstart'
```

Must report `OK Neovim version is: '0.12.4...'`. If it reports *out of date*, Step 1 did
not take effect — most likely a `PATH` ordering problem.

Then create a scratch document and open it:

```latex
\documentclass{article}
\begin{document}
\section{Test}
Math: $\alpha + \beta$.
\end{document}
```

Inside the buffer, check:

- `\alpha` renders as `α` (conceal is on, `conceallevel` should be 2)
- `<space>ll` starts continuous compilation, producing a PDF under `build/`
- `<space>lv` opens zathura at the cursor position
- ctrl-click in zathura jumps back to the source line (inverse SyncTeX)
- `<space>lt` opens the table of contents
- In math mode, typing `ff` expands to `\frac{}{}` (auto-snippet)

A quick programmatic check of the same things:

```bash
nvim --headless probe.tex -c 'lua vim.defer_fn(function()
  print("nvim: " .. tostring(vim.version()))
  print("conceallevel: " .. tostring(vim.wo.conceallevel))
  print("VimtexView: " .. tostring(vim.fn.exists(":VimtexView") == 2))
  print("autosnippets: " .. tostring(vim.tbl_count(require("luasnip").get_snippets("tex", {type="autosnippets"}) or {})))
  vim.cmd("qa!") end, 3500)'
```

Expect `0.12.4`, `conceallevel: 2`, `VimtexView: true`, `autosnippets: 149`.

---

## Key bindings

`maplocalleader` is `<space>`, so VimTeX's defaults read as:

| Key | Action |
| --- | --- |
| `<space>ll` | toggle continuous compilation |
| `<space>lv` | forward search — view PDF at cursor |
| `<space>lt` | table of contents |
| `<space>le` | errors / quickfix |
| `<space>lk` | kill compiler |
| `<space>lc` | clean aux files |
| `<space>f` | format buffer (latexindent) — manual, not on save |

Editing verbs worth knowing: `cse` change surrounding environment, `dse` delete it, `tse`
toggle starred, `csc`/`dsc` change/delete command, `tsd` toggle delimiters. Text objects:
`ie`/`ae` environment, `i$`/`a$` math, `id`/`ad` delimiters, `ic`/`ac` command.

---

## Machine-specific overrides

`lua/local.lua` is gitignored and sourced at the very end of `init.lua`. Put anything
host-specific there — it runs last and can override anything above it. It does **not**
exist by default and its absence is not an error.

One thing it cannot do: `maplocalleader` must be set before plugins load, so changing it
requires editing `init.lua:91` directly (and that change would then be shared with the
other machine).

The Kotlin LSP in `init.lua` is already guarded by a `vim.uv.fs_stat` check on its binary
path, so it simply will not register on a machine where it is not installed. No error.

---

## Known cross-machine caveats

- **TeX Live version follows the Ubuntu release.** If this laptop is on a different Ubuntu
  version than the work machine (that one is 24.04 → TeX Live 2023), the two will have
  different TeX package versions and a document can build on one and warn on the other.
  Report the `lsb_release -ds` result so this can be judged. The fix, if it ever bites, is
  upstream TeX Live via `install-tl` on both machines rather than apt.
- **Spell files are gitignored** (`spell/`). German spellcheck (`:setlocal spelllang=de`)
  re-downloads `de.utf-8.spl` on first use. Harmless, just not synced.
- **Terminal font** is configured outside the repo. If conceal renders as boxes instead of
  `α`, the terminal font lacks the glyphs — not a config problem.
- **`vim.g.have_nerd_font` is `false`** in the shared config. Only change it if *both*
  machines have a Nerd Font installed.

---

## Do not

- Do not edit `~/.config/nvim` — the config is complete and shared. Host differences belong
  in `lua/local.lua`.
- Do not run `:Lazy update` / `:Lazy sync`. Use `:Lazy restore` to match the lockfile.
- Do not add a `latex` treesitter parser. It conflicts with VimTeX's conceal.
- Do not re-add the `ppa:neovim-ppa/unstable` source.
