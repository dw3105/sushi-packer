local M = {}
local N = require("scripts.names")
local copy = require("scripts.copy")
local led = require("scripts.led")
local ledger = require("scripts.ledger")
local arms = require("scripts.arms")
local circuit = require("scripts.circuit")

local function boxes() storage.boxes = storage.boxes or {}; return storage.boxes end
local function valid(e) return e ~= nil and e.valid == true end
local function direction_name(direction)
  for _, d in ipairs(N.DIRS) do if defines.direction[d] == direction then return d end end
  return "north"
end
local function spill_at(surface, position, items)
  for _, item in ipairs(items or {}) do
    if item.name and item.count and item.count > 0 then
      surface.spill_item_stack({ position = position,
        stack = { name = item.name, count = item.count, quality = item.quality }, enable_looted = true })
    end
  end
end
local function spill(entity, items)
  spill_at(entity.surface, entity.position, items)
end
local function inventory_items(entity)
  if not entity.get_inventory then return {}, nil end
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
local function store_items(rec)
  local items = {}
  for lane = 1, 2 do
    local inv = rec.invs and rec.invs[lane]
    if inv and inv.valid ~= false then
      for _, item in ipairs(contents_as_array(inv.get_contents())) do
        if item.name and item.count and item.count > 0 then items[#items + 1] = item end
      end
    end
  end
  return items
end
local function migrate_old_box(rec)
  if not rec.box or rec.stores then return end
  local old, merged, order = rec.box, {}, {}
  local function add(item, lane)
    if not item or not item.name or not item.count or item.count <= 0 then return end
    lane = item.lane or lane
    if lane ~= 1 and lane ~= 2 then return end
    local key = item.name .. "\0" .. tostring(item.quality or "normal") .. "\0" .. lane
    if not merged[key] then
      merged[key] = { name = item.name, quality = item.quality or "normal", lane = lane, count = 0 }
      order[#order + 1] = key
    end
    merged[key].count = merged[key].count + item.count
  end
  for _, item in ipairs(old.partials or {}) do add(item, item.lane) end
  for lane = 1, 2 do for _, item in ipairs(old.ready and old.ready[lane] or {}) do add(item, lane) end end
  for lane = 1, 2 do
    local hold = old.hold and old.hold[lane]
    if hold and hold.name and hold.count and hold.count > 0 then
      add({ name = hold.name, quality = hold.quality, count = hold.count }, lane)
    end
  end
  rec.extra = {}
  for _, key in ipairs(order) do rec.extra[#rec.extra + 1] = merged[key] end
  rec.box, rec.ledger, rec.in_credit = nil, ledger.new(), nil
end

function M.get(entity)
  if not valid(entity) or not entity.unit_number then return nil end
  return boxes()[entity.unit_number]
end

function M.new_rec(entity)
  local tier = N.BODIES[entity.name]
  if not tier then return nil end
  local rec = { entity = entity, unit_number = entity.unit_number, tier = tier, dir = N.dir_name(entity.direction),
    ledger = ledger.new(), settings = copy.default_settings(), enabled = true,
    circuit_state = { last_flush = false }, out_credit = { 0, 0 }, in_credit = { 0, 0 }, next_poll = 0 }
  rec.settings.circuit.read = true
  boxes()[entity.unit_number] = rec; storage.sched = nil
  return rec
end

function M.on_built(e)
  local entity = e and e.entity
  if not valid(entity) then return end
  local tier = N.PLACERS[entity.name]
  local legacy = N.VARIANTS[entity.name]
  if tier or legacy then
    local dir = tier and direction_name(entity.direction) or legacy.dir
    tier = tier or legacy.tier
    local position, force, quality, surface = entity.position, entity.force, entity.quality, entity.surface
    local last_user = entity.last_user
    entity.destroy()
    entity = surface.create_entity({ name = N.body(tier), position = position, direction = defines.direction[dir],
      force = force, quality = quality, create_build_effect_smoke = false })
    if not valid(entity) then return end
    entity.last_user = last_user
  end
  if not N.BODIES[entity.name] then return end
  local rec = M.get(entity)
  local recovered = false
  if not rec then rec = M.take_stash(entity); recovered = rec ~= nil end
  local created = rec == nil
  rec = rec or M.new_rec(entity)
  rec.entity, rec.unit_number = entity, entity.unit_number
  rec.tier, rec.dir = N.BODIES[entity.name], N.dir_name(entity.direction)
  -- Body that arrives with control behaviour (blueprint, upgrade, clone) carries player's circuit settings: read them.
  -- Fresh body has none: write defaults. Asked before arms.create, which gives every body one (shut condition).
  local carried = entity.get_control_behavior and entity.get_control_behavior() ~= nil
  if created or recovered then arms.create(rec) end
  if e.tags and e.tags.sushi_packer then copy.import(rec, e.tags.sushi_packer) end
  if carried then circuit.sync(rec) else circuit.apply(rec) end
  arms.wire(rec, rec.settings.circuit.read ~= false)
  if created or recovered then led.create(rec) else led.ensure(rec) end
end

function M.on_removed(e)
  local entity = e and e.entity
  local rec = M.get(entity)
  if not rec then return end
  -- Upgrade = robot/platform mine of marked box (FND-0006). Hand mine of marked box returns hold as usual.
  if (e.robot or e.platform) and entity.to_be_upgraded and entity.to_be_upgraded() then
    M.stash(rec)
    return
  end
  local held = arms.drain_hands and arms.drain_hands(rec) or {}
  if e.buffer then
    for _, item in ipairs(store_items(rec)) do e.buffer.insert({ name = item.name, count = item.count, quality = item.quality }) end
    for _, item in ipairs(held) do e.buffer.insert({ name = item.name, count = item.count, quality = item.quality }) end
  else
    spill(entity, store_items(rec))
    spill(entity, held)
  end
  arms.destroy(rec)
  led.destroy(rec)
  boxes()[rec.unit_number] = nil; storage.sched = nil
end

function M.on_died(e)
  local entity = e and e.entity
  local rec = M.get(entity)
  if not rec then return end
  local held = arms.drain_hands and arms.drain_hands(rec) or {}
  spill(entity, store_items(rec))
  spill(entity, held)
  arms.destroy(rec)
  led.destroy(rec)
  boxes()[rec.unit_number] = nil; storage.sched = nil
end

function M.on_rotated(e)
  local entity=e and e.entity; local rec=M.get(entity); if not rec then return end
  local old=rec.led; rec.dir=N.dir_name(entity.direction)
  rec.belt, rec.front_was = nil, nil  -- neighbours changed sides
  arms.create(rec); led.destroy(rec); led.create(rec)
  if old then led.set(rec,old.state,old.visible) end
end

-- U-3 upgrade (FND-0006). The engine moves inventory; this preserves script state.
local function upgrade_key(entity)
  return entity.surface.index .. ":" .. entity.position.x .. ":" .. entity.position.y
end
local function prune_stash()
  storage.upgrade_stash = storage.upgrade_stash or {}
  for key, entry in pairs(storage.upgrade_stash) do
    if entry.tick < game.tick then
      local rec = entry.rec
      spill_at(entry.surface, entry.position, store_items(rec))
      arms.destroy(rec)
      storage.upgrade_stash[key] = nil
    end
  end
end
function M.stash(rec)
  local entity = rec.entity
  prune_stash()
  local wires = {}
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local connector = entity.get_wire_connector(id, false)
    if connector then
      for _, c in ipairs(connector.connections) do
        wires[#wires + 1] = { id = id, target = c.target.owner,
          target_id = c.target.wire_connector_id, origin = c.origin }
      end
    end
  end
  storage.upgrade_stash[upgrade_key(entity)] = { rec = rec, tick = game.tick,
    force = entity.force.index, wires = wires, surface = entity.surface, position = entity.position }
  led.destroy(rec)
  boxes()[rec.unit_number] = nil; storage.sched = nil
end
function M.take_stash(entity)
  prune_stash()
  local key = upgrade_key(entity)
  local entry = storage.upgrade_stash[key]
  if not entry or entry.tick ~= game.tick or entry.force ~= entity.force.index then return nil end
  local rec = entry.rec
  local tier = N.BODIES[entity.name]
  if not tier then return nil end
  rec.entity, rec.unit_number = entity, entity.unit_number
  rec.tier, rec.dir = tier, N.dir_name(entity.direction)
  rec.belt, rec.next_poll = nil, 0
  boxes()[entity.unit_number] = rec; storage.sched = nil
  for _, w in ipairs(entry.wires) do
    if valid(w.target) then
      local connector = entity.get_wire_connector(w.id, true)
      if connector then
        local connected = false
        for _, c in ipairs(connector.connections or {}) do
          if c.target and c.target.owner == w.target and c.target.wire_connector_id == w.target_id then
            connected = true; break
          end
        end
        if not connected then
          connector.connect_to(w.target.get_wire_connector(w.target_id, true), false, w.origin)
        end
      end
    end
  end
  storage.upgrade_stash[key] = nil
  return rec
end

function M.on_configuration_changed(data)
  local remove = {}
  for _, rec in pairs(boxes()) do
    if not valid(rec.entity) then arms.destroy(rec); remove[#remove + 1] = rec.unit_number else
      if rec.box and not rec.stores then
        migrate_old_box(rec)
        if N.VARIANTS[rec.entity.name] then M.migrate(rec) else arms.create(rec) end
      elseif N.VARIANTS[rec.entity.name] then M.migrate(rec)
      else
        rec.settings = rec.settings or copy.default_settings()
        rec.settings.circuit = rec.settings.circuit or copy.default_settings().circuit
        if rec.settings.circuit.read == nil then rec.settings.circuit.read = true end
        arms.ensure(rec)
      end
      led.ensure(rec)
    end
  end
  for _, unit in ipairs(remove) do boxes()[unit] = nil; storage.sched = nil end
end

local function insert_or_spill(rec, lane, item)
  local inv=rec.invs and rec.invs[lane]; local n=0
  if inv and inv.valid ~= false then n=inv.insert({name=item.name,count=item.count,quality=item.quality}) or 0 end
  if n < item.count then spill(rec.entity,{{name=item.name,count=item.count-n,quality=item.quality}}) end
end
function M.migrate(rec)
  if not rec or not valid(rec.entity) or not N.VARIANTS[rec.entity.name] then return rec end
  local old, unit, surface, old_led = rec.entity, rec.unit_number, rec.entity.surface, rec.led
  local contents=inventory_items(old); contents=contents_as_array(contents)
  local held=arms.drain_hands and arms.drain_hands(rec) or {}
  local wires={}
  for _,id in ipairs({defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
    local con=old.get_wire_connector and old.get_wire_connector(id,false)
    for _,c in ipairs(con and con.connections or {}) do if c.origin ~= defines.wire_origin.script then wires[#wires+1]={id=id,target=c.target.owner,target_id=c.target.wire_connector_id,origin=c.origin} end end
  end
  arms.destroy(rec,true)
  local body=surface.create_entity({name=N.body(rec.tier),position=old.position,direction=defines.direction[rec.dir],force=old.force,quality=old.quality,create_build_effect_smoke=false})
  if not valid(body) then
    for _,it in ipairs(contents) do spill(old,{it}) end; for _,it in ipairs(store_items(rec)) do spill(old,{it}) end
    for _,it in ipairs(held) do spill(old,{it}) end
    arms.destroy(rec); led.destroy(rec); old.destroy(); boxes()[unit]=nil; storage.sched=nil; return nil
  end
  rec.entity,rec.unit_number=body,body.unit_number; boxes()[unit]=nil; boxes()[body.unit_number]=rec; storage.sched=nil
  -- rec.extra (v1.14 saves, items put in from outside) names items that lie in the chest, with their lane: those go
  -- to that lane, only the rest of the chest goes to lane 1. Never both (items would double).
  local left = {}
  for _,it in ipairs(contents) do local k=it.name.."\0"..tostring(it.quality or "normal"); left[k]=(left[k] or 0)+it.count end
  for _,it in ipairs(rec.extra or {}) do
    local k=it.name.."\0"..tostring(it.quality or "normal")
    local n=math.min(it.count or 0,left[k] or 0)
    if n>0 then left[k]=left[k]-n; insert_or_spill(rec,it.lane or 1,{name=it.name,quality=it.quality,count=n}) end
  end
  rec.extra=nil
  for _,it in ipairs(contents) do
    local k=it.name.."\0"..tostring(it.quality or "normal")
    local n=math.min(it.count,left[k] or 0)
    if n>0 then left[k]=left[k]-n; insert_or_spill(rec,1,{name=it.name,quality=it.quality,count=n}) end
  end
  for _,it in ipairs(held) do insert_or_spill(rec,it.lane or 1,it) end
  for _,w in ipairs(wires) do if valid(w.target) then local c=body.get_wire_connector(w.id,true); c.connect_to(w.target.get_wire_connector(w.target_id,true),false,w.origin) end end
  old.destroy(); rec.settings=rec.settings or copy.default_settings(); rec.settings.circuit.read=true
  rec.belt, rec.front_was = nil, nil
  arms.create(rec); circuit.apply(rec)  -- apply after create: body gets its control behaviour there (shut)
  led.create(rec); if old_led then led.set(rec,old_led.state,old_led.visible) end; storage.sched=nil
  return rec
end

return M
