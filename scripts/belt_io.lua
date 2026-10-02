-- Belt access for the packer. All coordinates are tile centres.
local N = require("scripts.names")
local M = {}
local belt_speeds = {}
local lane_rates = {}
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

-- Right-hand unit vector per direction (splitter halves: left = negative side).
local right = { north = { 1, 0 }, east = { 0, 1 }, south = { -1, 0 }, west = { 0, -1 } }

-- FND-0015 (author blueprint 2026-09-27, probe `probe > splitter transport line numbering`): splitter facing box
-- direction touching box tile with one half. Behind: box takes that half's output lines (left 5/6, right 7/8).
-- In front: box writes that half's input lines (left 1/2, right 3/4). Returns line pair or nil.
local function splitter_lines(sp, entity, dir, sign)
  if not sp.valid or sp.type ~= "splitter" or sp.direction ~= direction_value(dir) then return nil end
  local offset, r = offsets[dir], right[dir]
  local tx, ty = entity.position.x + offset[1] * sign, entity.position.y + offset[2] * sign
  local dx, dy = tx - sp.position.x, ty - sp.position.y
  local forward, lateral = dx * offset[1] + dy * offset[2], dx * r[1] + dy * r[2]
  if math.abs(forward) > 0.01 or math.abs(math.abs(lateral) - 0.5) > 0.01 then return nil end
  local left = lateral < 0
  if sign == -1 then return left and { 5, 6 } or { 7, 8 } end
  return left and { 1, 2 } or { 3, 4 }
end

-- FND-0016 (author blueprint 2026-09-27, probe `probe > loader transport line numbering`): loaders (1x1, 2x1) and
-- linked belts facing box direction: lines 1/2 = lanes like belt. Behind must deliver (output), front must take (input).
-- 2x1 loader centre sits half a tile further from box than its belt-side tile.
local ENDPOINT = { ["loader-1x1"] = 0, loader = 0.5, ["linked-belt"] = 0 }
local function endpoint_lines(ent, entity, dir, sign)
  local shift = ENDPOINT[ent.type]
  if not shift or not ent.valid or ent.direction ~= direction_value(dir) then return nil end
  local kind = ent.type == "linked-belt" and ent.linked_belt_type or ent.loader_type
  if kind ~= (sign == -1 and "output" or "input") then return nil end
  local offset = offsets[dir]
  local cx = entity.position.x + offset[1] * sign * (1 + shift)
  local cy = entity.position.y + offset[2] * sign * (1 + shift)
  if math.abs(ent.position.x - cx) > 0.01 or math.abs(ent.position.y - cy) > 0.01 then return nil end
  return { 1, 2 }
end

local function neighbour_lines(ent, entity, dir, sign)
  if ent.type == "splitter" then return splitter_lines(ent, entity, dir, sign) end
  return endpoint_lines(ent, entity, dir, sign)
end

local function find_belt(entity, dir, sign)
  local offset = offsets[dir]
  if not offset then return nil end
  local position = entity.position
  local tx, ty = position.x + offset[1] * sign, position.y + offset[2] * sign
  local found = entity.surface.find_entities_filtered({
    position = { x = tx, y = ty },
    type = { "transport-belt", "underground-belt" },
  })
  for _, belt in ipairs(found) do
    if belt.valid then
      if sign == -1 and belt.direction == direction_value(dir) then
        if belt.type == "transport-belt" then return belt, { 1, 2 } end
        if belt.type == "underground-belt" and belt.belt_to_ground_type == "output" then return belt, { 1, 2 } end
      elseif sign == 1 and belt.direction == direction_value(dir) then
        if belt.type == "transport-belt" then return belt, { 1, 2 } end
        if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then return belt, { 1, 2 } end
      end
    end
  end
  local splitters = entity.surface.find_entities_filtered({
    area = { { tx - 0.1, ty - 0.1 }, { tx + 0.1, ty + 0.1 } }, type = { "splitter", "loader", "loader-1x1", "linked-belt" },
  })
  for _, sp in ipairs(splitters) do
    local lines = sp.valid and neighbour_lines(sp, entity, dir, sign)
    if lines then return sp, lines end
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
  if ENDPOINT[belt.type] or belt.type == "splitter" then return neighbour_lines(belt, entity, dir, sign) ~= nil end
  local offset = offsets[dir]
  if not offset then return false end
  local expected_x = entity.position.x + offset[1] * sign
  local expected_y = entity.position.y + offset[2] * sign
  if belt.position and (belt.position.x ~= expected_x or belt.position.y ~= expected_y) then return false end
  if belt.type == "transport-belt" then return true end
  return belt.type == "underground-belt" and belt.belt_to_ground_type == (sign == -1 and "output" or "input")
end

local PLAIN = { 1, 2 }

-- v15 perf: tick.on_tick tells current tick once (no `game.tick` read per call); a side checked this tick is not
-- re-checked for further calls in same tick.
local now
function M.set_tick(tick) now = tick end

local function ensure_lines(b, field, belt, map)
  local lines = b.lines[field]
  if type(lines) ~= "table" or type(lines[1]) == "number" then
    map = type(lines) == "table" and lines or map or PLAIN
    b.lines[field] = { belt.get_transport_line(map[1]), belt.get_transport_line(map[2]) }
  end
end

-- Returns belt-like entity on this side and its line pair for lanes 1/2.
local function cached(rec, field, sign)
  local b = rec.belt
  if not b then b = { behind = nil, front = nil, scan = {} }; rec.belt = b end
  if type(b.scan) ~= "table" then b.scan = {} end -- one rescan clock per side: a missing side never starves the other
  if type(b.lines) ~= "table" then b.lines = {} end
  local belt = b[field]
  local kind = b.kind and b.kind[field]
  local tick = now or game.tick or 0
  if belt and now and b.ok and b.ok[field] == now and type(b.lines[field]) == "table" and type(b.lines[field][1]) ~= "number" then
    return belt, PLAIN
  end
  if belt then
    if not kind then
      b.kind = b.kind or {}
      kind = belt.type
      b.kind[field] = kind
    end
    local valid = belt.valid
    local direction = valid and belt.direction
    if valid and direction == direction_value(rec.dir) then
      b.ok = b.ok or {}
      if kind == "transport-belt" or kind == "underground-belt" then
        b.checked = b.checked or {}
        if tick < (b.checked[field] or -60) + 60 then
          ensure_lines(b, field, belt, PLAIN)
          b.ok[field] = tick
          return belt, PLAIN
        end
        b.checked[field] = tick
        if matches(belt, rec.entity, rec.dir, sign) then
          ensure_lines(b, field, belt, PLAIN)
          b.ok[field] = tick
          return belt, PLAIN
        end
      elseif matches(belt, rec.entity, rec.dir, sign) then
        local map = b.lines[field]
        if type(map) ~= "table" or type(map[1]) ~= "number" then map = nil end
        if type(b.lines[field]) ~= "table" or type(b.lines[field][1]) == "number" then
          map = map or neighbour_lines(belt, rec.entity, rec.dir, sign) or PLAIN
          b.lines[field] = { belt.get_transport_line(map[1]), belt.get_transport_line(map[2]) }
        end
        b.ok[field] = tick
        return belt, map or PLAIN
      end
    end
    if not valid then b.scan[field] = tick - 60 end
  end
  b[field], b.lines[field] = nil, nil
  if b.kind then b.kind[field] = nil end
  if b.checked then b.checked[field] = nil end
  if b.ok then b.ok[field] = nil end
  if tick < (b.scan[field] or -60) + 60 then return nil end
  b.scan[field] = tick
  local lines
  belt, lines = find_belt(rec.entity, rec.dir, sign)
  b[field] = belt
  b.lines[field] = nil
  if belt then
    b.kind = b.kind or {}
    b.kind[field] = belt.type
    b.checked = b.checked or {}
    b.checked[field] = tick
    local map = lines or PLAIN
    b.lines[field] = { belt.get_transport_line(map[1]), belt.get_transport_line(map[2]) }
  end
  return belt, lines or PLAIN
end

local function transport_line(rec, field, lane, map)
  local lines = rec.belt and rec.belt.lines and rec.belt.lines[field]
  if lines then return lines[lane] end
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
  local counters = storage and storage.sp_counters
  local taken = { 0, 0 }
  local belt, map = cached(rec, "behind", -1)
  if not belt then return taken, nil end
  local eta = { nil, nil }
  -- FND-0011: lane that took an item last asks second next time, so a full box hands freed slots to lanes in turn
  -- (no starving lane). All-refused visits keep order (no parity lock with output cadence).
  local first = rec.pull_first == 2 and 2 or 1
  -- FND-0024 / FND-0030: take items that reach the belt end within this tick (position <= belt_speed), not only
  -- resting ones. Resting-only capped belts faster than turbo at 60/s and blue at 200/225 per lane (item gap 2.67
  -- ticks vs 2-tick visits). Detailed read only while the front item is still moving.
  -- FND-0031 / V11-7: window only above red (0.0625); yellow/red reach full rate on resting items (FND-0030), and
  -- the read cost 200 yellow boxes x1.05..x1.50 script time (bench 2026-09-29).
  local speed = belt_speed(belt) or 0
  local fast = speed > 0.0625
  for i = 0, 1 do
    local lane = i == 0 and first or 3 - first
    local line = transport_line(rec, "behind", lane, map)
    local tries = 0
    local detailed, di
    while tries < (budget[lane] or 0) do
      if #line == 0 then break end
      if line.can_insert_at(0) then
        if not fast then break end
        if not detailed then
          if counters then counters.reads = counters.reads + 1 end
          detailed, di = line.get_detailed_contents(), 1
        end
        local d = detailed[di]
        if not d or d.position > speed then break end
      end
      local s = line[1]
      local name = s.name
      local quality = s.quality and s.quality.name or "normal"
      local count = s.count  -- handle invalid once removed (engine, FND-0024)
      local accepted = sink(name, quality, lane, count)
      tries = tries + 1
      if accepted <= 0 then break end
      line.remove_item({ name = name, count = accepted, quality = quality })
      if counters then counters.pulls = counters.pulls + 1; counters.items_in = counters.items_in + accepted end
      if detailed and accepted >= count then di = di + 1 end
      taken[lane] = taken[lane] + 1
      rec.pull_first = 3 - lane
    end
  end
  -- ETA describes the leading item after any removals. Lane that took an item: next item sits >= 0.25 tile
  -- (belt item gap) behind, never sooner than next tier visit (PERF-3) -> skip costly detailed read.
  for lane = 1, 2 do
    local line = transport_line(rec, "behind", lane, map)
    if taken[lane] > 0 or #line == 0 then eta[lane] = nil
    elseif not line.can_insert_at(0) then eta[lane] = 0
    else
      if counters then counters.reads = counters.reads + 1 end
      local detailed = line.get_detailed_contents()
      -- fast belt: wake when item enters take window (position <= speed), not at belt end (FND-0024)
      local position = detailed[1].position
      if fast then position = math.max(speed / 2, position - speed) end
      eta[lane] = M.eta(position, speed)
    end
  end
  return taken, eta
end

-- v15 (F-1, V15-2): what waits on one lane of the belt-like entity behind the box: array {name, quality, count} or nil.
function M.behind_kinds(rec, lane)
  local belt = cached(rec, "behind", -1)
  if not belt then return nil end
  local line = transport_line(rec, "behind", lane)
  return line and line.get_contents() or nil
end

-- v17 (V17-5): belt running across in front. Both packer lanes go to its near lane: line 2 when it runs to the
-- right of packer travel ((its direction - packer direction) % 16 == 4), else line 1. Kept beside the "front"
-- cache (that one holds only neighbours running our way). Looked for at most once per 60 ticks.
local function across(rec)
  local b = rec.belt
  local tick = now or game.tick or 0
  local belt = b.across
  if belt then
    if belt.valid and tick < (b.across_at or -60) + 60 then return b.across_line end
  elseif tick < (b.across_scan or -60) + 60 then
    return nil
  end
  b.across, b.across_line, b.across_scan = nil, nil, tick
  local offset, e = offsets[rec.dir], rec.entity
  if not offset then return nil end
  local found = e.surface.find_entities_filtered({ position = { x = e.position.x + offset[1], y = e.position.y + offset[2] }, type = "transport-belt" })
  local mine = direction_value(rec.dir)
  for _, candidate in ipairs(found) do
    if candidate.valid and candidate.type == "transport-belt" then
      local turn = (candidate.direction - mine) % 16
      if turn == 4 or turn == 12 then
        b.across, b.across_at = candidate, tick
        b.across_line = candidate.get_transport_line(turn == 4 and 2 or 1)
        return b.across_line
      end
    end
  end
  return nil
end

-- v15 perf: may lane take one more belt item now? One engine call (plus side check once per tick).
function M.can_push(rec, lane)
  local belt = cached(rec, "front", 1)
  if not belt then
    -- back of near lane: belt fed only by packer is drawn and laid as a curve, its inner (near) lane is shorter than
    -- half a tile, so a fixed spot like 0.5 is refused (game 2026-10-02: split leftovers never merged out)
    local line = across(rec)
    return line ~= nil and line.can_insert_at_back()
  end
  local line = transport_line(rec, "front", lane)
  return line ~= nil and line.can_insert_at_back()
end

-- v17: what is in front? "ahead" = belt-like entity running our way (push rules), "across" = belt turned 90 degrees,
-- nil = nothing packer may feed (also belt facing packer).
function M.front_kind(rec)
  if cached(rec, "front", 1) then return "ahead" end
  if across(rec) then return "across" end
  return nil
end

function M.front_ok(rec)
  return M.front_kind(rec) ~= nil
end

-- spot (v20, optional): 1..3 = further belt spots of the front tile (0.25 tile apart, counted from line end), for
-- several pushes in one look; nil = back of line as always.
function M.push(rec, lane, item, belt_stack_size, spot)
  local counters = storage and storage.sp_counters
  local belt, map = cached(rec, "front", 1)
  local line
  if belt then
    line = transport_line(rec, "front", lane, map)
    if spot then
      local position = (spot - 1) * 0.25
      if not line.can_insert_at(position) then return 0 end
      if not line.insert_at(position, { name = item.name, count = item.count, quality = item.quality }, belt_stack_size) then return 0 end
    else
    if not line.can_insert_at_back() then return 0 end
    if not line.insert_at_back({ name = item.name, count = item.count, quality = item.quality }, belt_stack_size) then return 0 end
    end
  else
    line = across(rec)
    if not line or not line.can_insert_at_back() then return 0 end
    if not line.insert_at_back({ name = item.name, count = item.count, quality = item.quality }, belt_stack_size) then return 0 end
  end
  if counters then counters.pushes = counters.pushes + 1; counters.items_out = counters.items_out + item.count end
  return item.count
end

-- v9 (M-6): belt items per lane per tick for tier = live belt prototype speed x 4. Cached per tier: prototype-
-- derived, same on every client, fixed for the Lua state (prototypes change only with a reload). No prototype
-- (offline mocks) -> table value, not cached.
function M._reset_rates() lane_rates = {} end  -- tests only: mocks swap prototypes between tests

function M.lane_rate(tier)
  local cached_rate = lane_rates[tier]
  if cached_rate ~= nil then return cached_rate end
  local T = N.TIER[tier]
  local p = prototypes and prototypes.entity and prototypes.entity[T.belt]
  if p then
    local rate = p.belt_speed * 4
    lane_rates[tier] = rate
    return rate
  end
  return T.lane_rate or 0
end

-- Research-set belt stack (O-3 v7, author 2026-09-27): 1 + bonus, capped by engine max (utility constant,
-- 4 in vanilla, raised by mods). Never a literal cap.
function M.belt_stack_size(force)
  return math.min(prototypes.utility_constants.max_belt_stack_size, 1 + force.belt_stack_size_bonus)
end

return M
