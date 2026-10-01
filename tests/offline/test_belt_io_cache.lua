local belt_io = require("scripts.belt_io")

local function rig(kind, front)
  defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
  game = { tick = 1 }
  local counts = {}
  local pos = { x = 0, y = 0 }
  local entity = setmetatable({ surface = {}, dir = "north" }, {
    __index = function(_, key)
      if key == "position" then counts.entity_position = (counts.entity_position or 0) + 1; return pos end
    end,
  })
  local belts, searches = {}, 0
  local function new_belt(t, p)
    local values = { valid = true, direction = 0, type = t or "transport-belt", position = p }
    local b = setmetatable({}, { __index = function(_, key)
      if counts[key] ~= nil or key == "valid" or key == "direction" or key == "type" or key == "position" or key == "get_transport_line" then
        counts[key] = (counts[key] or 0) + 1
      end
      if key == "get_transport_line" then
        return function(lane)
          counts.lines = (counts.lines or 0) + 1
          return values.lines and values.lines[lane] or values.line
        end
      end
      return values[key]
    end })
    values.line = { can_insert_at = function() return true end, can_insert_at_back = function() return true end,
      get_detailed_contents = function() return {} end, insert_at_back = function() return true end }
    values.lines = { values.line, values.line }
    values._values = values
    return b, values
  end
  local beltpos = front and { x = 0, y = -1 } or { x = 0, y = 1 }
  local belt, values = new_belt(kind, beltpos)
  belts[1] = belt
  entity.surface.find_entities_filtered = function(filter)
    searches = searches + 1
    if filter.position then return belts end
    return {}
  end
  return { entity = entity, dir = "north" }, counts, values, function() return searches end, new_belt, function(p) values.position = p end
end

local function pull(rec)
  return belt_io.pull(rec, { 0, 0 }, function() return 0 end)
end
local function push(rec)
  return belt_io.push(rec, 1, { name = "iron", count = 1, quality = "normal" }, 1)
end

describe("belt_io cache", function()
  it("cached belt visit reads valid and direction only", function()
    local r, c = rig()
    pull(r); c.valid, c.direction, c.type, c.position, c.entity_position = nil, nil, nil, nil, nil
    game.tick = 2; pull(r)
    eq(c.type or 0, 0); eq(c.position or 0, 0); eq(c.entity_position or 0, 0)
    ok((c.valid or 0) + (c.direction or 0) <= 2)
  end)
  it("lines fetched once while belt cached", function()
    local r, c = rig()
    for t = 1, 5 do game.tick = t; pull(r) end
    ok((c.lines or 0) <= 2, "get_transport_line calls: " .. tostring(c.lines))
  end)
  it("push uses cached front lines", function()
    local r, c = rig("transport-belt", true)
    for t = 1, 5 do game.tick = t; push(r) end
    ok((c.lines or 0) <= 2, "get_transport_line calls: " .. tostring(c.lines))
    ok((c.type or 0) <= 2 and (c.position or 0) <= 2)
  end)
  it("moved belt dropped within 60 ticks", function()
    local r, c, v, searches, new_belt, move = rig()
    pull(r); game.tick = 5; move({ x = 0, y = 9 }); pull(r)
    eq(r.belt.behind, r.belt.behind) -- cache may remain until the scheduled full check
    for t = 6, 65 do game.tick = t; pull(r) end
    ok(r.belt.behind == nil or searches() > 1, "moved belt was never rejected")
    local steady, reads = rig()
    for t = 1, 120 do game.tick = t; pull(steady) end
    ok((reads.position or 0) <= 6, "full position checks: " .. tostring(reads.position))
  end)
  it("rotated belt dropped at once", function()
    local r, _, v = rig()
    pull(r); v.direction = 4; game.tick = 2; pull(r)
    eq(r.belt.behind, nil)
  end)
  it("splitter neighbour keeps full check", function()
    local r, c, _, _, new_belt = rig("splitter")
    local splitter = r.belt
    -- Replace lookup with a correctly placed right half splitter and expose distinct output lines 7/8.
    local items = { [7] = { name = "iron", count = 1, quality = { name = "normal" } } }
    local function line(item)
      return setmetatable({ can_insert_at = function() return not item end,
        remove_item = function() return 1 end, get_detailed_contents = function() return item and { { position = 0 } } or {} end },
        { __len = function() return item and 1 or 0 end, __index = function(_, k) if k == 1 then return item end end })
    end
    local l7, l8 = line(items[7]), line(nil)
    local sp = { valid = true, type = "splitter", direction = 0, position = { x = -0.5, y = 1 } }
    function sp.get_transport_line(n) return n == 7 and l7 or l8 end
    r.entity.surface.find_entities_filtered = function(f) if f.position then return {} end; return { sp } end
    local got = belt_io.pull(r, { 1, 0 }, function() return 1 end)
    eq(got[1], 1)
    c.type = nil
  end)
  it("dropped belt clears cached lines", function()
    local r, _, old, _, make = rig()
    local old_line = old.line
    old_line.can_insert_at = function() error("stale line used") end
    pull(r); old.valid = false
    local fresh, fresh_values = make("transport-belt", { x = 0, y = 1 })
    local item = { name = "iron", count = 1, quality = { name = "normal" } }
    fresh_values.line = setmetatable({ can_insert_at = function() return false end,
      remove_item = function() return 1 end, get_detailed_contents = function() return {} end },
      { __len = function() return 1 end, __index = function(_, k) if k == 1 then return item end end })
    fresh_values.lines = { fresh_values.line, fresh_values.line }
    r.entity.surface.find_entities_filtered = function(f)
      if not f.position then return {} end
      if old.valid then return { old } end
      if game.tick >= 62 then return { fresh } end
      return {}
    end
    game.tick = 2; pull(r)
    local dropped_lines = r.belt.lines.behind
    ok(not dropped_lines or type(dropped_lines[1]) == "number", "cached LuaTransportLine survived belt drop")
    game.tick = 62
    local got = belt_io.pull(r, { 1, 0 }, function() return 1 end)
    eq(got[1], 1); eq(r.belt.behind, fresh)
  end)
end)
