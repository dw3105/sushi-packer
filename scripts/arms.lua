-- Hidden lane stores and lane-locked inserters for each box.
local N = require("scripts.names")
local M = {}

function M.count(speed)
  for _, row in ipairs(N.ARMS) do
    if row.max >= speed then return row.n end
  end
  return N.ARMS[#N.ARMS].n
end

local function _valid(part)
  return part ~= nil and part.valid == true  -- engine objects are userdata (2.0+), never tables
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

function M.create(rec)
  local entity = rec.entity
  local surface, pos, force = entity.surface, entity.position, entity.force
  local old_arms = rec.arms or {}
  local old_out = rec.out or {}
  -- Preserve every item in an inserter hand before replacing that inserter.
  for lane = 1, 2 do
    for _, group in ipairs({ old_arms[lane] or {}, old_out[lane] or {} }) do
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
              local box_inv = entity.get_inventory(defines.inventory.chest)
              local inserted = box_inv.insert(stack)
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
    local fx, fy = _delta(rec.dir)
    local s = lane == 1 and 0.25 or -0.25
    local drop = { x = pos.x + fx + fy * s, y = pos.y + fy - fx * s }
    for _ = 1, N.OUT_ARMS do
      local arm = surface.create_entity { name = N.OUT, position = pos, force = force }
      arm.destructible = false
      arm.pickup_position = pos
      arm.pickup_target = rec.stores[lane]
      arm.drop_position = drop
      rec.out[lane][#rec.out[lane] + 1] = arm
    end
  end
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local box_connector = entity.get_wire_connector(id, true)
    for lane = 1, 2 do
      rec.stores[lane].get_wire_connector(id, true).connect_to(box_connector, false, defines.wire_origin.script)
    end
  end
  rec.paused = { false, false }
  rec.skip = { "", "" }
  rec.out_paused = { false, false }
  rec.hand = nil
end

function M.destroy(rec, keep_stores)
  for lane = 1, 2 do
    for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do _destroy(arm) end
    for _, arm in ipairs((rec.out and rec.out[lane]) or {}) do _destroy(arm) end
  end
  rec.arms = nil
  rec.out, rec.out_paused, rec.hand = nil, nil, nil
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
  for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do
    if _valid(arm) then
      arm.use_filters = #kinds > 0
      arm.inserter_filter_mode = "blacklist"
      for i = 1, N.ARM_FILTERS do
        local kind = kinds[i]
        arm.set_filter(i, kind and { name = kind.name, quality = kind.quality, comparator = "=" } or nil)
      end
    end
  end
  rec.skip[lane] = signature
end

-- F-1: does an arm of this lane hold an item whose kind has no slot in the lane store yet?
function M.need_slot(rec, lane, contents)
  for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do
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
  return false
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
  for i, arm in ipairs((rec.out and rec.out[lane]) or {}) do
    if _valid(arm) then
      local hand = arm.held_stack
      if hand and hand.valid_for_read then
        list[#list + 1] = { arm = i, name = hand.name, quality = hand.quality.name, count = hand.count }
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
    for _, group in ipairs({ (rec.arms and rec.arms[lane]) or {}, (rec.out and rec.out[lane]) or {} }) do
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

function M.ensure(rec)
  local expected = M.count(prototypes.entity[N.TIER[rec.tier].belt].belt_speed)
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
    if not outs or #outs ~= N.OUT_ARMS then
      broken = true
    else
      for _, arm in ipairs(outs) do if not _valid(arm) then broken = true; break end end
    end
  end
  if broken then M.create(rec); return true end
  return false
end

return M
