# nvim-phh

Neovim support for PHH (.phh/.phhs). Uses the exact same artifacts every other editor in this project does:
`tree-sitter-phh`'s grammar and canonical `queries/` for highlighting, and
`phh-ls` itself for diagnostics/hover/completion via Neovim's built-in LSP
client, nothing reimplemented here.

## Setup

```lua
require("phh").setup({
  server_path = "/absolute/path/to/phh-ls/build/phh-ls", -- default: "phh-ls" on PATH
  registry_path = "/absolute/path/to/phh/registry", -- required, no default
  -- grammar_path / actions_grammar_path default to the sibling
  -- tree-sitter-phh / tree-sitter-phh-actions checkouts used throughout
  -- this project; override if yours live elsewhere.
})
```

Add this plugin's directory to Neovim's runtime path however your plugin
manager expects (or `vim.opt.runtimepath:append(...)` by hand), then call
`setup()` from your config.

## What's implemented

- **Filetype detection** (`ftdetect/phh.lua`): `.phh`/`.phhs` → `phh`.
- **Tree-sitter highlighting**: both grammars ship pre-compiled as
  `parser/phh.so` and `parser/phh_actions.so` (built from
  `../tree-sitter-phh` and `../tree-sitter-phh-actions`'s generated
  `src/parser.c`, no external scanner needed, see those repos'
  `grammar.js` files). `setup()` registers them with
  `vim.treesitter.language.add` and loads their queries
  (`highlights`/`injections`/`folds`/`indents` for `phh`, `highlights` for
  `phh_actions`) directly from the canonical grammar checkouts via
  `vim.treesitter.query.set`, rather than vendoring copies, the one
  canonical `queries/` directory stays in `tree-sitter-phh`, per that
  repo's own README.
- **LSP**: `vim.lsp.start` on every `phh` buffer, via Neovim's built-in
  client, no `nvim-lspconfig` dependency.
- **`:checkhealth phh`** (`lua/phh/health.lua`): reports whether `phh-ls`
  is reachable, the registry is present and complete, both compiled
  grammars exist, and both grammars' query files are reachable at the
  configured paths.

## How this was verified

`test/headless_test.lua`, run via:

```sh
nvim --headless --clean -u NONE -l nvim-phh/test/headless_test.lua
```

drives the real plugin against the real corpus (`../phh/corpus/`) inside
an actual (headless) Neovim instance, not a mock. For every valid and
invalid fixture, it opens the file, waits for the real `phh-ls` process to
attach and respond, and checks: correct `filetype`, the `phh-ls` LSP client
actually attached, diagnostics matching the corpus's own zero/non-zero
expectations (`phh/corpus/README.md`), and the tree-sitter highlighter
active with no parse error. It also exercises `hover` on the `variant`
field through the same LSP client. **Everything passed on the first real
run**, 31/31 checks, including every corpus file. `:checkhealth phh` was
separately run and confirmed all-green.

Unlike `vscode-phh` (where the Extension Development Host GUI window was
deliberately not auto-launched) and `vim-phh` (where real engine
limitations were found and had to be worked around), nothing here needed a
workaround, Neovim's built-in tree-sitter and LSP client worked exactly
as expected, which is itself worth recording: this was the
cheapest editor integration of the four, as expected going in.

## Known limitations

- **Compiled `.so` parsers are checked in rather than built on install.**
  Fine for this project's local, sibling-checkout development workflow;
  real distribution (per-platform binaries, or wiring into
  `nvim-treesitter`'s own installer with a published grammar repo URL) is
  later work, not done here.
- **No `:checkhealth`-driven install instructions beyond path reporting**:
  it tells you what's missing, not how to fix it beyond what the error
  text already says.
