-- End-to-end smoke test for nvim-phh, run via:
--   nvim --headless --clean -u NONE -l nvim-phh/test/headless_test.lua
--
-- Mirrors the discipline of phh-ls/tests/lsp_smoke_test.py and
-- vscode-phh/test/tokenize-corpus.js: drives the real plugin against real
-- corpus files inside a real (headless) Neovim instance, not a mock.

local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
vim.opt.runtimepath:append(root .. "/nvim-phh")

local failures = 0
local function check(label, cond)
  print(("[%s] %s"):format(cond and "ok" or "FAIL", label))
  if not cond then failures = failures + 1 end
end

-- ftdetect/*.lua files are normally sourced automatically by Neovim's
-- plugin-loading machinery on startup; --clean -u NONE skips that, so load
-- it explicitly here the same way a real Neovim startup would.
dofile(root .. "/nvim-phh/ftdetect/phh.lua")

local phh = require("phh")
phh.setup({
  server_path = root .. "/phh-ls/build/phh-ls",
  registry_path = root .. "/phh/registry",
})

check("setup() recorded state", phh._state ~= nil)

local function open_and_wait(path)
  vim.cmd.edit(path)
  local bufnr = vim.api.nvim_get_current_buf()
  check(path .. ": filetype detected as phh", vim.bo[bufnr].filetype == "phh")

  local got_diagnostics = false
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    buffer = bufnr,
    once = true,
    callback = function() got_diagnostics = true end,
  })

  local attached = vim.wait(5000, function()
    return #vim.lsp.get_clients({ bufnr = bufnr, name = "phh-ls" }) > 0
  end, 50)
  check(path .. ": phh-ls client attached", attached)

  vim.wait(3000, function() return got_diagnostics end, 50)

  return bufnr
end

local valid_files = vim.fn.glob(root .. "/phh/corpus/valid/*.phh", false, true)
vim.list_extend(valid_files, vim.fn.glob(root .. "/phh/corpus/valid/*.phhs", false, true))
local invalid_files = vim.fn.glob(root .. "/phh/corpus/invalid/*.phh", false, true)

for _, path in ipairs(valid_files) do
  local bufnr = open_and_wait(path)
  local diags = vim.diagnostic.get(bufnr)
  check(vim.fn.fnamemodify(path, ":t") .. ": zero diagnostics", #diags == 0)

  local highlighter_active = vim.treesitter.highlighter.active[bufnr] ~= nil
  check(vim.fn.fnamemodify(path, ":t") .. ": tree-sitter highlighter active", highlighter_active)
end

for _, path in ipairs(invalid_files) do
  local bufnr = open_and_wait(path)
  local diags = vim.diagnostic.get(bufnr)
  check(vim.fn.fnamemodify(path, ":t") .. ": at least one diagnostic", #diags >= 1)
end

-- Hover, via the same built-in LSP client, on the first valid file's
-- `variant` field (same position vscode-phh/test and lsp_smoke_test.py
-- already know lands there: line 1 (0-indexed), the field's value).
do
  local path = valid_files[1]
  local bufnr = open_and_wait(path)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "phh-ls" })
  if #clients > 0 then
    local result = clients[1]:request_sync(
      "textDocument/hover",
      {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        position = { line = 1, character = 11 },
      },
      5000,
      bufnr
    )
    local hover_ok = result and result.result and result.result.contents ~= nil
    check("hover on variant field returns content", hover_ok)
  else
    check("hover on variant field returns content", false)
  end
end

print()
if failures > 0 then
  print(("%d FAILURE(S)"):format(failures))
  vim.cmd("cquit 1")
else
  print("All checks passed.")
  vim.cmd("qa")
end
