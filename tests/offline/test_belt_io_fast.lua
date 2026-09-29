-- v9 S2 (FND-0024): belts faster than turbo lose rate if pull takes only items resting at position 0.
-- Mock line: items with positions (0 = belt end); can_insert_at(0) true while front item > 0 (engine, measured).
defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
local belt_io = require("scripts.belt_io")

local function rig(name, speed, positions)
  game = { tick = 1 }
  prototypes = { entity = { [name] = { belt_speed = speed } } }
  local items = {}
  for i, p in ipairs(positions) do items[i] = { name = "iron", count = 1, position = p } end
  local line = setmetatable({}, {
    __len = function() return #items end,
    -- engine: LuaItemStack handle dies when its item leaves the line (read after remove_item errors)
    __index = function(_, k)
      if type(k) ~= "number" or not items[k] then return nil end
      local it = items[k]
      return setmetatable({}, { __index = function(_, f)
        for _, x in ipairs(items) do if x == it then return it[f] end end
        error("LuaItemStack API call when LuaItemStack was invalid.")
      end })
    end,
  })
  function line.can_insert_at(pos) return not (pos == 0 and items[1] and items[1].position == 0) end
  function line.remove_item(x) table.remove(items, 1); return x.count end
  function line.get_detailed_contents()
    local out = {}
    for i, it in ipairs(items) do out[i] = { position = it.position, stack = { name = it.name, count = it.count } } end
    return out
  end
  local empty = setmetatable({}, { __len = function() return 0 end })
  function empty.can_insert_at() return true end
  function empty.get_detailed_contents() return {} end
  local belt = { valid = true, type = "transport-belt", direction = 0, name = name }
  function belt.get_transport_line(lane) return lane == 1 and line or empty end
  local entity = { valid = true, position = { x = 0, y = 0 }, surface = { find_entities_filtered = function() return { belt } end } }
  return { entity = entity, dir = "north" }, items
end

describe("belt_io fast", function()
  it("fast belt takes item arriving this tick", function()
    -- kr-superior 0.1875: probe t=181 front item at 0.063 (reaches end this tick), next at 0.313 (not yet)
    local rec = rig("fast-a", 0.1875, { 0.063, 0.313 })
    local got = belt_io.pull(rec, { 2, 0 }, function(_, _, _, c) return c end)
    eq(got[1], 1)
  end)
  it("270 per s belt takes every item within one tick of end", function()
    local rec = rig("fast-b", 0.5625, { 0.05, 0.30, 0.55, 0.80 })
    local got = belt_io.pull(rec, { 3, 0 }, function(_, _, _, c) return c end)
    eq(got[1], 3)
  end)
  it("budget still caps fast take", function()
    local rec = rig("fast-c", 0.5625, { 0.063, 0.313, 0.563 })
    local got = belt_io.pull(rec, { 1, 0 }, function(_, _, _, c) return c end)
    eq(got[1], 1)
  end)
  it("turbo and slower take item reaching end this tick", function()
    -- FND-0030: take window for all speeds (was resting-only for turbo and slower; blue capped 200/225)
    local rec = rig("turbo-a", 0.125, { 0.063, 0.313 })
    local got = belt_io.pull(rec, { 2, 0 }, function(_, _, _, c) return c end)
    eq(got[1], 1)
    local rec2 = rig("turbo-b", 0.125, { 0, 0.25 })
    eq(belt_io.pull(rec2, { 2, 0 }, function(_, _, _, c) return c end)[1], 1)
  end)
  it("fast belt eta counts to take window not belt end", function()
    -- hyper 0.15625: probe t=182 front item 0.188 -> takeable next tick (0.031 <= speed); eta to end = 2 overslept
    local rec = rig("fast-e", 0.15625, { 0.188, 0.438 })
    local got, eta = belt_io.pull(rec, { 2, 0 }, function(_, _, _, c) return c end)
    eq(got[1], 0); eq(eta[1], 1)
  end)
  it("refused item stops fast lane", function()
    local rec, items = rig("fast-d", 0.5625, { 0.063, 0.313 })
    local got = belt_io.pull(rec, { 3, 0 }, function() return 0 end)
    eq(got[1], 0); eq(#items, 2)
  end)
end)
