local M = {}
local N = require("scripts.names")
local led = require("scripts.led")
local ledger = require("scripts.ledger")
local arms = require("scripts.arms")
local circuit = require("scripts.circuit")

local function get_rec(entity)
  if not entity or not entity.valid or not entity.unit_number then return nil end
  return storage.boxes and storage.boxes[entity.unit_number]
end

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[clone(k)] = clone(v) end
  return out
end

function M.default_settings()
  return { timeout_mode = "global", timeout_s = 0, filters = {},
    circuit = { enable = false, cond = { comparator = ">", constant = 0 }, read = true, flush = false } }
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
  if not bp then return end
  if bp.object_name == "LuaRecord" then
    if not bp.valid or bp.type ~= "blueprint" or not bp.valid_for_write then return end
  elseif not bp.valid_for_read or not bp.is_blueprint then
    return
  end
  local entities = bp.get_blueprint_entities()
  if not entities then return end
  local mapping = e.mapping and e.mapping.get and e.mapping.get() or {}
  for _, ent in ipairs(entities) do
    local tier = N.BODIES[ent.name]
    if tier then
      local index = ent.entity_number
      local rec = mapping[index] and get_rec(mapping[index])
      if rec then
        ent.tags = ent.tags or {}
        ent.tags.sushi_packer = M.export(rec)
      end
    end
  end
  bp.set_blueprint_entities(entities)
end

function M.on_settings_pasted(e)
  local src, dst = get_rec(e.source), get_rec(e.destination)
  if src and dst then M.import(dst, M.export(src)); circuit.sync(dst); arms.wire(dst,dst.settings.circuit.read ~= false) end
end

function M.on_cloned(e)
  local src, dst = get_rec(e.source), e.destination
  if not src or not dst then return end
  if not dst or not dst.valid or not N.BODIES[dst.name] then return end
  storage.boxes = storage.boxes or {}
  local tier = N.BODIES[dst.name]
  local rec = { entity = dst, unit_number = dst.unit_number, tier = tier, dir = N.dir_name(dst.direction),
    ledger = ledger.new(), settings = M.default_settings(), enabled = true,
    circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0 }
  storage.boxes[dst.unit_number] = rec; storage.sched = nil  -- tick schedule rebuilt
  M.import(rec, M.export(src))
  arms.create(rec)
  circuit.sync(rec)
  for lane = 1, 2 do
    local source = src.invs and src.invs[lane]
    local destination = rec.invs and rec.invs[lane]
    if source and destination and source.valid ~= false then
      for _, stack in ipairs(source.get_contents()) do
        destination.insert({ name = stack.name, quality = stack.quality, count = stack.count })
      end
    end
  end
  led.create(rec)
end

return M
