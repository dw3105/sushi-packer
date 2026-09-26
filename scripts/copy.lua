local M = {}
local N = require("scripts.names")

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[clone(k)] = clone(v) end
  return out
end

function M.default_settings()
  return { timeout_mode = "global", timeout_s = 0, filters = {},
    circuit = { enable = false, cond = { comparator = ">", constant = 0 }, flush = false } }
end

function M.export(rec) return clone(rec.settings) end

function M.import(rec, settings)
  local defaults, incoming = M.default_settings(), clone(settings or {})
  local function fill(dst, src)
    for k, v in pairs(src) do
      if type(v) == "table" then
        if type(dst[k]) ~= "table" then dst[k] = {} end
        fill(dst[k], v)
      elseif dst[k] == nil then dst[k] = clone(v) end
    end
  end
  fill(incoming, defaults)
  rec.settings = incoming
end

function M.on_setup_blueprint(e)
  local bp = e.record or e.stack
  if not bp or not bp.valid_for_read or not bp.is_blueprint then return end
  local entities = bp.get_blueprint_entities()
  if not entities then return end
  local mapping = e.mapping and e.mapping.get and e.mapping.get() or {}
  local registry = require("scripts.registry")
  for _, ent in ipairs(entities) do
    local v = N and N.VARIANTS[ent.name]
    if v then
      local index = ent.entity_number
      local rec = mapping[index] and registry.get(mapping[index])
      if rec then
        ent.name = N.placer(v.tier)
        ent.direction = defines.direction[v.dir]
        ent.tags = ent.tags or {}
        ent.tags.sushi_packer = M.export(rec)
      end
    end
  end
  bp.set_blueprint_entities(entities)
end

function M.on_settings_pasted(e)
  local registry = require("scripts.registry")
  local src, dst = registry.get(e.source), registry.get(e.destination)
  if src and dst then M.import(dst, M.export(src)) end
end

function M.on_cloned(e)
  local registry = require("scripts.registry")
  local src, dst = registry.get(e.source), e.destination
  if not src or not dst then return end
  local rec = registry.new_rec(dst)
  M.import(rec, M.export(src))
  local function clone_box(t)
    if type(t) ~= "table" then return t end
    local o = {}; for k, v in pairs(t) do o[clone_box(k)] = clone_box(v) end; return o
  end
  rec.box = clone_box(src.box)
  require("scripts.led").create(rec)
end

return M
