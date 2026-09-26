-- Belt access for the packer. All coordinates are tile centres.
local M = {}

local offsets = {
  north = { 0, -1 }, east = { 1, 0 }, south = { 0, 1 }, west = { -1, 0 },
}
local opposite = { north = "south", east = "west", south = "north", west = "east" }

local function direction_value(dir)
  return ({ north = defines.direction.north, east = defines.direction.east,
    south = defines.direction.south, west = defines.direction.west })[dir]
end

local function find_belt(entity, dir, sign)
  local offset = offsets[dir]
  if not offset then return nil end
  local position = entity.position
  local found = entity.surface.find_entities_filtered({
    position = { x = position.x + offset[1] * sign, y = position.y + offset[2] * sign },
    type = { "transport-belt", "underground-belt" },
  })
  for _, belt in ipairs(found) do
    if belt.valid then
      if sign == -1 and belt.direction == direction_value(dir) then
        if belt.type == "transport-belt" then return belt end
        if belt.type == "underground-belt" and belt.belt_to_ground_type == "output" then return belt end
      elseif sign == 1 and belt.direction == direction_value(dir) then
        if belt.type == "transport-belt" then return belt end
        if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then return belt end
      end
    end
  end
  return nil
end

function M.behind(entity, dir)
  return find_belt(entity, dir, -1)
end

function M.front(entity, dir)
  return find_belt(entity, dir, 1)
end

local function matches(belt, entity, dir, sign)
  if not belt or not belt.valid or belt.direction ~= direction_value(dir) then return false end
  local offset = offsets[dir]
  if not offset then return false end
  local expected_x = entity.position.x + offset[1] * sign
  local expected_y = entity.position.y + offset[2] * sign
  if belt.position and (belt.position.x ~= expected_x or belt.position.y ~= expected_y) then return false end
  if belt.type == "transport-belt" then return true end
  return belt.type == "underground-belt" and belt.belt_to_ground_type == (sign == -1 and "output" or "input")
end

local function cached(rec, field, sign)
  local b = rec.belt
  if not b then b = { behind = nil, front = nil, scan = {} }; rec.belt = b end
  if type(b.scan) ~= "table" then b.scan = {} end -- one rescan clock per side: a missing side never starves the other
  local belt = b[field]
  if matches(belt, rec.entity, rec.dir, sign) then return belt end
  b[field] = nil
  local tick = game.tick or 0
  if tick < (b.scan[field] or -60) + 60 then return nil end
  b.scan[field] = tick
  belt = find_belt(rec.entity, rec.dir, sign)
  b[field] = belt
  return belt
end

function M.pull(rec, budget, sink)
  local taken = { 0, 0 }
  if budget[1] < 1 and budget[2] < 1 then return taken end
  local belt = cached(rec, "behind", -1)
  if not belt then return taken end
  for lane = 1, 2 do
    local line = belt.get_transport_line(lane)
    local tries = 0
    while tries < budget[lane] do
      local details = line.get_detailed_contents()
      local selected, position = nil, math.huge
      for _, detail in ipairs(details) do
        if detail.position < position then selected, position = detail, detail.position end
      end
      if not selected or position > 0.125 then break end
      local name = selected.stack.name
      local quality = selected.stack.quality and selected.stack.quality.name or "normal"
      local count = selected.stack.count
      local accepted = sink(name, quality, lane, count)
      tries = tries + 1
      if accepted <= 0 then break end
      local removed = line.remove_item({ name = name, quality = quality, count = accepted })
      if removed <= 0 then break end
      taken[lane] = taken[lane] + 1
    end
  end
  return taken
end

function M.push(rec, lane, item, belt_stack_size)
  local belt = cached(rec, "front", 1)
  if not belt then return 0 end
  local line = belt.get_transport_line(lane)
  if not line.can_insert_at_back() then return 0 end
  if line.insert_at_back({ name = item.name, count = item.count, quality = item.quality }, belt_stack_size) then
    return item.count
  end
  return 0
end

function M.belt_stack_size(force)
  return math.min(4, 1 + force.belt_stack_size_bonus)
end

return M
