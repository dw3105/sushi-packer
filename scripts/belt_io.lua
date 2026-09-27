-- Belt access for the packer. All coordinates are tile centres.
local M = {}
local belt_speeds = {}
setmetatable(M, { __index = function(t, key)
  if key == "speed" or key == "eta" then return rawget(t, "_" .. key) end
end })

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

function M._eta(position, speed)
  if not speed or speed <= 0 then return nil end
  return math.max(0, math.ceil(position / speed))
end

local function belt_speed(belt)
  if not belt then return nil end
  local name = belt.name or (belt.prototype and belt.prototype.name)
  if not name then return belt.prototype and belt.prototype.belt_speed end
  if belt_speeds[name] == nil then
    local prototype = belt.prototype or (prototypes and prototypes.entity and prototypes.entity[name])
    belt_speeds[name] = prototype and prototype.belt_speed or false
  end
  return belt_speeds[name] or nil
end

function M._speed(rec)
  if not rec or not rec.entity or not rec.entity.surface
    or type(rec.entity.surface.find_entities_filtered) ~= "function" then return nil end
  return belt_speed(cached(rec, "behind", -1))
end

function M.pull(rec, budget, sink)
  local taken = { 0, 0 }
  local belt = cached(rec, "behind", -1)
  if not belt then return taken, nil end
  local eta = { nil, nil }
  for lane = 1, 2 do
    local line = belt.get_transport_line(lane)
    local count = #line
    local tries = 0
    while tries < (budget[lane] or 0) do
      if count == 0 or line.can_insert_at(0) then break end
      local s = line[1]
      local name = s.name
      local quality = s.quality and s.quality.name or "normal"
      local count = s.count
      local accepted = sink(name, quality, lane, count)
      tries = tries + 1
      if accepted <= 0 then break end
      line.remove_item({ name = name, count = accepted, quality = quality })
      taken[lane] = taken[lane] + 1
      count = #line
    end
  end
  -- ETA describes the leading item after any removals. Lane that took an item: next item sits >= 0.25 tile
  -- (belt item gap) behind, never sooner than next tier visit (PERF-3) -> skip costly detailed read.
  for lane = 1, 2 do
    local line = belt.get_transport_line(lane)
    if taken[lane] > 0 or #line == 0 then eta[lane] = nil
    elseif not line.can_insert_at(0) then eta[lane] = 0
    else
      local detailed = line.get_detailed_contents()
      eta[lane] = M.eta(detailed[1].position, belt_speed(belt))
    end
  end
  return taken, eta
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

-- Research-set belt stack (O-3 v7, author 2026-09-27): 1 + bonus, capped by engine max (utility constant,
-- 4 in vanilla, raised by mods). Never a literal cap.
function M.belt_stack_size(force)
  return math.min(prototypes.utility_constants.max_belt_stack_size, 1 + force.belt_stack_size_bonus)
end

return M
