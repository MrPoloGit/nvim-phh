-- Neovim support for PHH (.phh/.phhs), 
--
-- This plugin registers the SAME artifacts every other editor in this project
-- uses, tree-sitter-phh's compiled grammar + its canonical queries/ for
-- highlighting, and phh-ls itself for diagnostics/hover/completion via
-- Neovim's built-in LSP client, rather than reimplementing anything.
--
-- By design, this module does nothing on require(); call M.setup() from
-- your config (e.g. a lazy.nvim/packer `config` function).

local M = {}

local function plugin_root()
  local source = debug.getinfo(1, "S").source
  local this_file = source:sub(2) -- strip the leading '@' chunk-name marker
  -- this_file is .../nvim-phh/lua/phh/init.lua; three ":h" hops up from the
  -- file reach the plugin root (init.lua -> phh/ -> lua/ -> nvim-phh/).
  return vim.fn.fnamemodify(this_file, ":h:h:h")
end

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local content = fd:read("*a")
  fd:close()
  return content
end

-- Loads one grammar's queries into Neovim's in-memory query registry
-- (vim.treesitter.query.set), reading them directly from the canonical
-- tree-sitter-phh(-actions) checkout rather than a vendored copy inside
-- this plugin, see tree-sitter-phh/README.md: "queries/ ... consumed by
-- multiple editor integrations." `names` lists which query files that
-- grammar actually ships (tree-sitter-phh has more than phh_actions does).
local function load_queries(lang, grammar_path, names)
  for _, name in ipairs(names) do
    local path = grammar_path .. "/queries/" .. name .. ".scm"
    local content = read_file(path)
    if content then
      local ok, err = pcall(vim.treesitter.query.set, lang, name, content)
      if not ok then
        vim.notify(
          ("phh: failed to register %s query for %s: %s"):format(name, lang, err),
          vim.log.levels.WARN
        )
      end
    else
      vim.notify(
        ("phh: query file not found: %s (grammar_path may be wrong)"):format(path),
        vim.log.levels.WARN
      )
    end
  end
end

-- Exposed so lua/phh/health.lua can report exactly what setup() resolved
-- and used, without the two modules duplicating the default-computation
-- logic.
M._state = nil

function M.setup(opts)
  opts = opts or {}
  local root = plugin_root()

  local config = {
    server_path = opts.server_path or "phh-ls",
    registry_path = opts.registry_path,
    -- Defaults assume the sibling-repository layout used throughout this
    -- project (phh-ls, tree-sitter-phh, tree-sitter-phh-actions, nvim-phh
    -- all live next to each other); override both paths explicitly once
    -- these are installed independently rather than checked out together.
    grammar_path = opts.grammar_path or vim.fn.fnamemodify(root .. "/../tree-sitter-phh", ":p"),
    actions_grammar_path = opts.actions_grammar_path
      or vim.fn.fnamemodify(root .. "/../tree-sitter-phh-actions", ":p"),
  }
  M._state = config

  if not config.registry_path or config.registry_path == "" then
    vim.notify(
      "phh: setup() needs registry_path ',
      vim.log.levels.ERROR
    )
    return
  end

  -- 1. Tree-sitter: register both compiled grammars this plugin bundles,
  --    then load their queries from the canonical grammar checkouts.
  local ok_phh, err_phh = pcall(vim.treesitter.language.add, "phh", {
    path = root .. "/parser/phh.so",
  })
  if not ok_phh then
    vim.notify("phh: failed to load parser/phh.so: " .. tostring(err_phh), vim.log.levels.ERROR)
  end

  local ok_actions, err_actions = pcall(vim.treesitter.language.add, "phh_actions", {
    path = root .. "/parser/phh_actions.so",
  })
  if not ok_actions then
    vim.notify(
      "phh: failed to load parser/phh_actions.so: " .. tostring(err_actions),
      vim.log.levels.ERROR
    )
  end

  if ok_phh then
    load_queries("phh", config.grammar_path, { "highlights", "injections", "folds", "indents" })
  end
  if ok_actions then
    load_queries("phh_actions", config.actions_grammar_path, { "highlights" })
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "phh",
    group = vim.api.nvim_create_augroup("phh_treesitter", { clear = true }),
    callback = function(args)
      if ok_phh then
        pcall(vim.treesitter.start, args.buf, "phh")
      end
    end,
  })

  -- 2. LSP: start phh-ls over stdio for every phh buffer, via Neovim's
  --    built-in client, no nvim-lspconfig dependency, and no custom
  --    protocol extension needed to work.
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "phh",
    group = vim.api.nvim_create_augroup("phh_lsp", { clear = true }),
    callback = function(args)
      vim.lsp.start({
        name = "phh-ls",
        cmd = { config.server_path, config.registry_path },
        root_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":p:h"),
      })
    end,
  })
end

return M
