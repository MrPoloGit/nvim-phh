-- :checkhealth phh, 's "documented
-- install path" requirement. Reports on exactly the things M.setup() in
-- lua/phh/init.lua needs to have gone right: phh-ls reachable, the
-- registry present, and both compiled grammars loadable.

local M = {}

local function file_exists(path)
  local fd = io.open(path, "r")
  if fd then
    fd:close()
    return true
  end
  return false
end

local function dir_exists(path)
  return vim.fn.isdirectory(path) == 1
end

function M.check()
  local health = vim.health or require("health")
  health.start("phh")

  local phh = require("phh")
  local state = phh._state

  if not state then
    health.warn('require("phh").setup() has not been called yet, nothing else can be checked.')
    return
  end

  -- phh-ls reachable
  if vim.fn.executable(state.server_path) == 1 then
    health.ok(("phh-ls found: %s"):format(state.server_path))
  else
    health.error(
      ("phh-ls not found or not executable: %s"):format(state.server_path),
      { "Set phh.server_path to an absolute path, or add phh-ls to your PATH." }
    )
  end

  -- registry present
  local registry_files = { "variants.json", "fields.json", "actions.json", "cards.json" }
  if dir_exists(state.registry_path) then
    local missing = {}
    for _, name in ipairs(registry_files) do
      if not file_exists(state.registry_path .. "/" .. name) then
        table.insert(missing, name)
      end
    end
    if #missing == 0 then
      health.ok(("registry found: %s"):format(state.registry_path))
    else
      health.error(
        ("registry at %s is missing: %s"):format(state.registry_path, table.concat(missing, ", "))
      )
    end
  else
    health.error(("registry_path does not exist: %s"):format(state.registry_path))
  end

  -- compiled grammars
  for _, lang in ipairs({ "phh", "phh_actions" }) do
    local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
    local so_path = root .. "/parser/" .. lang .. ".so"
    if file_exists(so_path) then
      health.ok(("%s.so present: %s"):format(lang, so_path))
    else
      health.error(("%s.so not found: %s (rebuild with the sibling grammar repo)"):format(lang, so_path))
    end
  end

  -- queries reachable from the canonical grammar checkouts
  local query_checks = {
    { lang = "phh", path = state.grammar_path, names = { "highlights", "injections", "folds", "indents" } },
    { lang = "phh_actions", path = state.actions_grammar_path, names = { "highlights" } },
  }
  for _, c in ipairs(query_checks) do
    local missing = {}
    for _, name in ipairs(c.names) do
      if not file_exists(c.path .. "/queries/" .. name .. ".scm") then
        table.insert(missing, name)
      end
    end
    if #missing == 0 then
      health.ok(("%s queries found at %s"):format(c.lang, c.path))
    else
      health.warn(
        ("%s: missing query files at %s: %s"):format(c.lang, c.path, table.concat(missing, ", "))
      )
    end
  end
end

return M
