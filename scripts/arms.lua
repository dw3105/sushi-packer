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
  for lane = 1, 2 do
    for _, arm in ipairs(old_arms[lane] or {}) do _destroy(arm) end
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
  end
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    local box_connector = entity.get_wire_connector(id, true)
    for lane = 1, 2 do
      rec.stores[lane].get_wire_connector(id, true).connect_to(box_connector, false, defines.wire_origin.script)
    end
  end
  rec.paused = { false, false }
  rec.skip = { "", "" }
end

function M.destroy(rec, keep_stores)
  for lane = 1, 2 do
    for _, arm in ipairs((rec.arms and rec.arms[lane]) or {}) do _destroy(arm) end
  end
  rec.arms = nil
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
  end
  if broken then M.create(rec); return true end
  return false
end

return M
