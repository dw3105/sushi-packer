local M = {}
local N = require("scripts.names")
local core = require("scripts.core")
local copy = require("scripts.copy")
local led = require("scripts.led")

local function boxes() storage.boxes = storage.boxes or {}; return storage.boxes end
local function valid(e) return e and e.valid end
local function direction_name(direction)
  for _, d in ipairs(N.DIRS) do if defines.direction[d] == direction then return d end end
  return "north"
end
local function spill(entity, items)
  for _, item in ipairs(items or {}) do
    if item.name and item.count and item.count > 0 then
      entity.surface.spill_item_stack({ position = entity.position,
        stack = { name = item.name, count = item.count, quality = item.quality }, enable_looted = true })
    end
  end
end
local function inventory_items(entity)
  local inv = entity.get_inventory(defines.inventory.chest)
  return inv and inv.valid and inv.get_contents() or {}, inv
end
local function contents_as_array(contents)
  local items = {}
  for key, value in pairs(contents or {}) do
    if type(value) == "table" then
      items[#items + 1] = { name = value.name or key, quality = value.quality, count = value.count }
    else
      items[#items + 1] = { name = key, count = value }
    end
  end
  return items
end

function M.get(entity)
  if not valid(entity) or not entity.unit_number then return nil end
  return boxes()[entity.unit_number]
end

function M.new_rec(entity)
  local v = N.VARIANTS[entity.name]
  if not v then return nil end
  local rec = { entity = entity, unit_number = entity.unit_number, tier = v.tier, dir = v.dir,
    box = core.new_box(), settings = copy.default_settings(), enabled = true,
    circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0 }
  boxes()[entity.unit_number] = rec
  return rec
end

function M.on_built(e)
  local entity = e and e.entity
  if not valid(entity) then return end
  local tier = N.PLACERS[entity.name]
  if tier then
    local dir, position, force, quality, surface = direction_name(entity.direction), entity.position, entity.force, entity.quality, entity.surface
    local last_user = entity.last_user
    entity.destroy()
    entity = surface.create_entity({ name = N.variant(tier, dir), position = position,
      force = force, quality = quality, create_build_effect_smoke = false })
    if not valid(entity) then return end
    entity.last_user = last_user
  end
  if not N.VARIANTS[entity.name] then return end
  local rec = M.get(entity)
  local created = rec == nil
  rec = rec or M.new_rec(entity)
  if e.tags and e.tags.sushi_packer then copy.import(rec, e.tags.sushi_packer) end
  if created then led.create(rec) else led.ensure(rec) end
end

function M.on_removed(e)
  local entity = e and e.entity
  local rec = M.get(entity)
  if not rec then return end
  local hold = core.hold_items(rec.box)
  if e.buffer then
    for _, item in ipairs(hold) do e.buffer.insert({ name = item.name, count = item.count, quality = item.quality }) end
  else
    spill(entity, hold)
  end
  core.clear_hold(rec.box)
  led.destroy(rec)
  boxes()[rec.unit_number] = nil
end

function M.on_died(e)
  local entity = e and e.entity
  local rec = M.get(entity)
  if not rec then return end
  local contents = inventory_items(entity)
  spill(entity, contents_as_array(contents))
  spill(entity, core.hold_items(rec.box))
  led.destroy(rec)
  boxes()[rec.unit_number] = nil
end

function M.swap(rec, new_dir)
  if not rec or not valid(rec.entity) then return rec end
  local old, old_unit, old_led = rec.entity, rec.unit_number, rec.led
  local contents = inventory_items(old)
  local wires = {}
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local connector = old.get_wire_connector(id, false)
    if connector then
      for _, c in ipairs(connector.connections) do
        wires[#wires + 1] = { id = id, target = c.target.owner,
          target_id = c.target.wire_connector_id, origin = c.origin }
      end
    end
  end
  local position, force, quality, surface, tier = old.position, old.force, old.quality, old.surface, rec.tier
  led.destroy(rec)
  old.destroy()
  local entity = surface.create_entity({ name = N.variant(tier, new_dir), position = position,
    force = force, quality = quality, create_build_effect_smoke = false })
  if not valid(entity) then boxes()[old_unit] = nil; return nil end
  local inv = entity.get_inventory(defines.inventory.chest)
  if inv then for _, item in ipairs(contents_as_array(contents)) do inv.insert(item) end end
  rec.entity, rec.unit_number, rec.dir = entity, entity.unit_number, new_dir
  boxes()[old_unit] = nil
  boxes()[entity.unit_number] = rec
  for _, w in ipairs(wires) do
    if valid(w.target) then
      local connector = entity.get_wire_connector(w.id, true)
      if connector then connector.connect_to(w.target.get_wire_connector(w.target_id, true), false, w.origin) end
    end
  end
  led.create(rec)
  if old_led then led.set(rec, old_led.state, old_led.visible) end
  return rec
end

function M.on_rotate_input(e, reverse)
  local player = game.get_player(e.player_index)
  local rec = player and M.get(player.selected)
  if not rec then return end
  local index = 1
  for i, dir in ipairs(N.DIRS) do if dir == rec.dir then index = i; break end end
  index = (index - 1 + (reverse and -1 or 1)) % #N.DIRS + 1
  M.swap(rec, N.DIRS[index])
end

function M.on_configuration_changed(data)
  local remove = {}
  for _, rec in pairs(boxes()) do
    if not valid(rec.entity) then remove[#remove + 1] = rec.unit_number else led.ensure(rec) end
  end
  for _, unit in ipairs(remove) do boxes()[unit] = nil end
end

return M
