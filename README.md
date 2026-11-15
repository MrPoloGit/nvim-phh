# nvim-phh

Neovim support for PHH (.phh/.phhs).

## Setup

```lua
require("phh").setup({
  server_path = "/absolute/path/to/phh-ls/build/phh-ls", -- default: "phh-ls" on PATH
  registry_path = "/absolute/path/to/phh-data/registry", -- required, no default
  -- grammar_path / actions_grammar_path default to the sibling
  -- tree-sitter-phh / tree-sitter-phh-actions checkouts used throughout
  -- this project; override if yours live elsewhere.
})
```

Add this plugin's directory to Neovim's runtime path however your plugin
manager expects (or `vim.opt.runtimepath:append(...)` by hand), then call
`setup()` from your config.

**Not listed anywhere.** This repo is pushed to
`github.com/MrPoloGit/nvim-phh`, usable today by any plugin manager
that takes a plain git URL (lazy.nvim, packer.nvim, etc.), but it isn't
listed in awesome-neovim or any other curated index, nothing has been
submitted anywhere.
