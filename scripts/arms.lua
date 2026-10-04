-- Hidden lane stores and lane-locked inserters for each box.
local N = require("scripts.names")
local M = {}
local ARROW = "utility/fluid_indication_arrow"
local ARROW_ORIENTATION = { north = 0, east = 0.25, south = 0.5, west = 0.75 }

function M.count(speed)
  for _, row in ipairs(N.ARMS) do
    if row.max >= speed then return row.n end
  end
  return N.ARMS[#N.ARMS].n
end

local function _valid(part)
  return part ~= nil and part.valid == true  -- engine objects are userdata (2.0+), never tables
end

local function _in_hands(rec)
  local pattern = N.ARM_HANDS
  local n = #pattern
  for lane = 1, 2 do
    for i, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do
      if _valid(arm) then
        local size = pattern[(i - 1) % n + 1]
        if size > N.ARM_HAND then size = N.ARM_HAND end
        arm.inserter_stack_size_override = size
      end
    end
  end
  rec.in_hands = table.concat(pattern, ",")
end

local function _opposite(dir)
  if dir == "north" then return "south" end
  if dir == "east" then return "west" end
  if dir == "south" then return "north" end
  return "east"
end

local function _delta(dir)
  if dir == "north" then return 0, -1 end
  if dir == "east" then return 1, 0 end
  if dir == "south" then return 0, 1 end
  return -1, 0
end

local function _destroy(part)
  if _valid(part) then part.destroy() end
end

local function _arrow(rec)
  local arrow = rec.arrow
  local orientation = ARROW_ORIENTATION[rec.dir]
  if _valid(arrow) then
    if arrow.orientation ~= orientation then arrow.orientation = orientation end
    return
  end
  local entity = rec.entity
  rec.arrow = rendering.draw_sprite { sprite = ARROW, target = entity, surface = entity.surface,
    only_in_alt_mode = true, orientation = orientation, render_layer = "entity-info-icon" }
end

local _out_positions
local _apply_aim

-- v22 (V22-2, FND-0054): hood = script-drawn picture on the body (render object), not a hidden entity: the entity
-- cost script time on every packer. Hood entity of an older save is removed here. Writes only what changed.
local function _hood(rec)
  local h = rec.hood
  if h ~= nil and h.valid and h.object_name ~= "LuaRenderObject" then h.destroy(); h = nil end
  local want = N.hood_sprite(rec.tier, rec.dir)
  if h ~= nil and h.valid then
    if h.sprite ~= want then h.sprite = want end
    _arrow(rec)
    return
  end
  local entity = rec.entity
  rec.hood = rendering.draw_sprite { sprite = want, target = entity, surface = entity.surface, render_layer = "object" }
  _arrow(rec)
end

function M.create(rec)
  local entity = rec.entity
  local surface, pos, force = entity.surface, entity.position, entity.force
  local old_arms = rec.arms or {}
  local old_out = rec.out or {}
  local old_mop = rec.mop or {}
  -- Preserve every item in an inserter hand before replacing that inserter.
  for lane = 1, 2 do
    for _, group in ipairs({ old_arms[lane] or {}, old_out[lane] or {}, old_mop[lane] or {} }) do
      for _, arm in ipairs(group) do
        if _valid(arm) then
          local held = arm.held_stack
          if held and held.valid_for_read then
            local remaining = held.count
            local stack = { name = held.name, count = remaining, quality = held.quality.name }
            local inv = rec.invs and rec.invs[lane]
            if _valid(rec.stores and rec.stores[lane]) and inv then
              local inserted = inv.insert(stack)
              remaining = remaining - inserted
            end
            if remaining > 0 then
              stack.count = remaining
              surface.spill_item_stack { position = pos, stack = stack }
            end
          end
        end
      end
    end
  end
  for lane = 1, 2 do
    for _, arm in ipairs(old_arms[lane] or {}) do _destroy(arm) end
    for _, arm in ipairs(old_out[lane] or {}) do _destroy(arm) end
    for _, arm in ipairs(old_mop[lane] or {}) do _destroy(arm) end
  end

  rec.stores = rec.stores or {}
  rec.invs = rec.invs or {}
  for lane = 1, 2 do
    if not _valid(rec.stores[lane]) then
      rec.stores[lane] = surface.create_entity { name = N.STORE, position = pos, force = force }
    end
    rec.stores[lane].destructible = false
    rec.invs[lane] = rec.stores[lane].get_inventory(defines.inventory.chest)
  end

  local speed = prototypes.entity[N.TIER[rec.tier].belt].belt_speed
  local n = M.count(speed)
  local dx, dy = _delta(_opposite(rec.dir))
  local pickup = { x = pos.x + dx, y = pos.y + dy }
  rec.arms = { {}, {} }
  rec.out = { {}, {} }
  rec.mop = { {}, {} }
  -- hand size = force belt stack now (tick writes it again when research changes it)
  local uc = prototypes.utility_constants
  local bss = 1 + (force.belt_stack_size_bonus or 0)
  local max = uc and uc.max_belt_stack_size or N.MAX_BELT_STACK
  if bss > max then bss = max end
  for lane = 1, 2 do
    for _ = 1, n do
      local arm = surface.create_entity { name = N.ARM, position = pos, force = force }
      arm.destructible = false
      arm.pickup_position = pickup
      arm.drop_position = pos
      arm.pickup_from_left_lane = lane == 1
      arm.pickup_from_right_lane = lane == 2
      arm.drop_target = rec.stores[lane]
      rec.arms[lane][#rec.arms[lane] + 1] = arm
    end
    for _ = 1, N.MOP_ARMS do
      local arm = surface.create_entity { name = N.ARM, position = pos, force = force }
      arm.destructible = false
      arm.pickup_position = pos
      arm.drop_position = pos
      arm.pickup_from_left_lane = lane == 1
      arm.pickup_from_right_lane = lane == 2
      arm.pickup_target = entity
      arm.drop_target = rec.stores[lane]
      rec.mop[lane][#rec.mop[lane] + 1] = arm
    end
    local out_name = N.out_name(speed)
    if not prototypes.entity[out_name] then out_name = N.OUT end  -- belt of tier changed after data stage: fast arm
    for _ = 1, N.out_count(speed) do
      local arm = surface.create_entity { name = out_name, position = pos, force = force }
      arm.destructible = false
      arm.inserter_stack_size_override = bss  -- before it can take anything: hand = belt stack from first tick
      -- starts paused: an out arm with nothing in front drops on the ground, and fast tiers finish a swing before
      -- the first look. Look unpauses when front is there (game 2026-10-02: upgrade to red put stored items on ground)
      arm.disabled_by_script = true
      arm.pickup_target = rec.stores[lane]
      rec.out[lane][#rec.out[lane] + 1] = arm
    end
  end
  _in_hands(rec)
  rec.paused = { false, false }
  rec.skip = { "", "" }
  rec.out_paused = { true, true }
  rec.hand = bss
  rec.steer = nil  -- fresh out arms carry no filters
  _hood(rec)
  M.shut(entity)
  rec.aim = nil
  _apply_aim(rec, "ahead")
  rec.wired = nil
  M.wire(rec, not (rec.settings and rec.settings.circuit and rec.settings.circuit.read == false))
end

function M.destroy(rec, keep_stores)
  for lane = 1, 2 do
    for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do _destroy(arm) end
    for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do _destroy(arm) end
    for _, arm in ipairs((rec.mop and rec.mop[lane]) or {}) do _destroy(arm) end
  end
  rec.arms = nil
  rec.out, rec.out_paused, rec.hand = nil, nil, nil
  rec.mop = nil
  _destroy(rec.hood)
  _destroy(rec.arrow)
  rec.hood, rec.arrow, rec.aim, rec.wired = nil, nil, nil, nil
  if not keep_stores then
    for lane = 1, 2 do _destroy(rec.stores and rec.stores[lane]) end
    rec.stores, rec.invs = nil, nil
  end
end

function M.pause(rec, lane, paused)
  rec.paused = rec.paused or {}
  if rec.paused[lane] == paused then return end
  for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do
    if _valid(arm) then arm.disabled_by_script = paused end
  end
  for _, arm in ipairs((rec.mop and rec.mop[lane]) or {}) do
    if _valid(arm) then arm.disabled_by_script = paused end
  end
  rec.paused[lane] = paused
end

local function _signature(kinds)
  local fields = {}
  for i, kind in ipairs(kinds or {}) do
    fields[i] = tostring(kind.name or "") .. "\0" .. tostring(kind.quality or "")
  end
  return table.concat(fields, "\1")
end

function M.skip(rec, lane, kinds)
  if #kinds == 0 and rec.skip and rec.skip[lane] == "" then return end  -- common case: nothing to skip, nothing set
  local signature = _signature(kinds)
  rec.skip = rec.skip or { "", "" }
  if rec.skip[lane] == signature then return end
  for _, group in ipairs({ (rec.arms and rec.arms[lane]) or {}, (rec.mop and rec.mop[lane]) or {} }) do
    for _, arm in ipairs(group) do
      if _valid(arm) then
        arm.use_filters = #kinds > 0
        arm.inserter_filter_mode = "blacklist"
        for i = 1, N.ARM_FILTERS do
          local kind = kinds[i]
          arm.set_filter(i, kind and { name = kind.name, quality = kind.quality, comparator = "=" } or nil)
        end
      end
    end
  end
  rec.skip[lane] = signature
  local counters = storage and storage.sp_counters
  if counters then counters.filter_writes = (counters.filter_writes or 0) + 1 end
end

-- F-1: does an arm of this lane hold an item whose kind has no slot in the lane store yet?
function M.need_slot(rec, lane, contents)
  for _, group in ipairs({ (rec.arms and rec.arms[lane]) or {}, (rec.mop and rec.mop[lane]) or {} }) do
    for _, arm in ipairs(group) do
      if _valid(arm) then
        local held = arm.held_stack
        if held and held.valid_for_read then
          local name, quality, found = held.name, held.quality.name, false
          for i = 1, #contents do
            local c = contents[i]
            if c.name == name and c.quality == quality then found = true; break end
          end
          if not found then return true end
        end
      end
    end
  end
  return false
end

-- v20 (V20-1): kinds out arms of a lane may take (whitelist), nil = anything (filters off). 5 filter slots per arm:
-- with more kinds each arm gets its own window of the list. Writes only when the list changed; returns true then.
function M.steer(rec, lane, kinds)
  rec.steer = rec.steer or {}
  if kinds == nil then
    if rec.steer[lane] == nil then return false end
    for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do
      if _valid(arm) then arm.use_filters = false end
    end
    rec.steer[lane] = nil
    return true
  end
  local signature = _signature(kinds)
  if rec.steer[lane] == signature then return false end
  local n = #kinds
  for j, arm in ipairs((rec.out and rec.out[lane]) or {}) do
    if _valid(arm) then
      arm.use_filters = true
      arm.inserter_filter_mode = "whitelist"
      for i = 1, N.ARM_FILTERS do
        local kind = i <= n and kinds[(j + i - 2) % n + 1] or nil
        arm.set_filter(i, kind and { name = kind.name, quality = kind.quality, comparator = "=" } or nil)
      end
    end
  end
  rec.steer[lane] = signature
  return true
end

function M.pause_out(rec, lane, paused)
  rec.out_paused = rec.out_paused or {}
  if rec.out_paused[lane] == paused then return end
  for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do
    if _valid(arm) then arm.disabled_by_script = paused end
  end
  rec.out_paused[lane] = paused
end

function M.hand(rec, bss)
  if rec.hand == bss then return end
  for lane = 1, 2 do
    for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do
      if _valid(arm) then arm.inserter_stack_size_override = bss end
    end
  end
  rec.hand = bss
end

local held_lists = { {}, {} }
function M.held(rec, lane)
  local list = held_lists[lane]
  for i = #list, 1, -1 do list[i] = nil end
  local outs = rec.out and rec.out[lane]
  if outs then
    for i = 1, #outs do
      local arm = outs[i]
      if _valid(arm) then  -- kept: another mod may destroy hidden parts; reading a dead arm would stop the game
        local hand = arm.held_stack
        if hand and hand.valid_for_read then
          list[#list + 1] = { arm = i, name = hand.name, quality = hand.quality.name, count = hand.count }
        end
      end
    end
  end
  return list
end

function M.clear_held(rec, lane, index)
  local arm = rec.out and rec.out[lane] and rec.out[lane][index]
  if _valid(arm) then
    local held = arm.held_stack
    if held and held.valid_for_read then held.clear() end
  end
end

function M.drain_hands(rec)
  local items = {}
  for lane = 1, 2 do
    for _, group in ipairs({ (rec.arms and rec.arms[lane]) or {}, (rec.out and rec.out[lane]) or {}, (rec.mop and rec.mop[lane]) or {} }) do
      for _, arm in ipairs(group) do
        if _valid(arm) then
          local held = arm.held_stack
          if held and held.valid_for_read then
            items[#items + 1] = { name = held.name, quality = held.quality.name, count = held.count, lane = lane }
            held.clear()
          end
        end
      end
    end
  end
  return items
end

_out_positions = function(pos, dir, lane, kind)
  local fx, fy = _delta(dir)
  local s = lane == 1 and 0.25 or -0.25
  local forward, side = 1, s
  if kind == "across" then forward, side = 0.75, 0.4 * s end
  local ddx, ddy = forward * fx + side * fy, forward * fy - side * fx
  return { x = pos.x + ddx, y = pos.y + ddy },
    { x = pos.x - 0.3 * ddx, y = pos.y - 0.3 * ddy }
end

function M.aim_out(rec, kind)
  if rec.aim == kind then return end
  _apply_aim(rec, kind)
end

_apply_aim = function(rec, kind)
  local pos = rec.entity.position
  for lane = 1, 2 do
    for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do
      if _valid(arm) then
        local drop, pick = _out_positions(pos, rec.dir, lane, kind)
        arm.drop_position = drop
        arm.pickup_position = pick
        -- writing pickup_position makes engine pick a new target at that spot (belt body): name lane store again
        -- (seen in game 2026-10-02: out arms waited on body, nothing left packer)
        arm.pickup_target = rec.stores[lane]
      end
    end
  end
  rec.aim = kind
end

function M.wire(rec, on)
  if rec.wired == on then return end
  local entity = rec.entity
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local body = entity.get_wire_connector(id, true)
    for lane = 1, 2 do
      local store = rec.stores and rec.stores[lane]
      if _valid(store) then
        local connector = store.get_wire_connector(id, true)
        if on then connector.connect_to(body, false, defines.wire_origin.script)
        else connector.disconnect_from(body, defines.wire_origin.script) end
      end
    end
  end
  rec.wired = on
end

function M.shut(entity)
  local cb = entity.get_or_create_control_behavior()
  cb.connect_to_logistic_network = true
  cb.logistic_condition = N.SHUT
end

function M.ensure(rec)
  local speed = prototypes.entity[N.TIER[rec.tier].belt].belt_speed
  local expected = M.count(speed)
  local expected_out = N.out_count(speed)
  local broken = false
  for lane = 1, 2 do
    if not _valid(rec.stores and rec.stores[lane]) then broken = true end
    local lane_arms = rec.arms and rec.arms[lane]
    if not lane_arms or #lane_arms ~= expected then
      broken = true
    else
      for _, arm in ipairs(lane_arms) do if not _valid(arm) then broken = true; break end end
    end
    local outs = rec.out and rec.out[lane]
    if not outs or #outs ~= expected_out then
      broken = true
    else
      for _, arm in ipairs(outs) do if not _valid(arm) then broken = true; break end end
    end
    local mops = rec.mop and rec.mop[lane]
    if not mops or #mops ~= N.MOP_ARMS then broken = true
    else for _, arm in ipairs(mops) do if not _valid(arm) then broken = true; break end end end
  end
  if broken then M.create(rec); return true end
  if not _valid(rec.hood) or rec.hood.object_name ~= "LuaRenderObject" or not _valid(rec.arrow) then _hood(rec) end
  if rec.in_hands ~= table.concat(N.ARM_HANDS, ",") then _in_hands(rec) end
  return false
end

return M
