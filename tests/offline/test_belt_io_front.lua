-- v16 seam: belt_io.front_ok(rec) = same answer as "push would find a front belt".
local function line() return { can_insert_at_back = function() return true end, insert_at_back = function() return true end } end
local function belt(type_, dir, x, y)
  return { valid = true, type = type_, name = "b", direction = dir, position = { x = x, y = y }, belt_to_ground_type = "input",
    get_transport_line = function() return line() end }
end
local function rec_with(found)
  local surface = { find_entities_filtered = function(spec) if spec.position then return found else return {} end end }
  return { dir = "north", entity = { valid = true, position = { x = 0.5, y = 0.5 }, surface = surface } }
end
describe("belt_io front", function()
  before_each = nil
  it("front_ok true with belt of same direction in front", function()
    _G.defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    _G.game = { tick = 0 }
    package.loaded["scripts.belt_io"] = nil
    local io_ = require("scripts.belt_io")
    io_.set_tick(0)
    eq(io_.front_ok(rec_with({ belt("transport-belt", 0, 0.5, -0.5) })), true)
  end)
  it("front_ok false without front or with sideways belt", function()
    _G.defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    _G.game = { tick = 0 }
    package.loaded["scripts.belt_io"] = nil
    local io_ = require("scripts.belt_io")
    io_.set_tick(0)
    eq(io_.front_ok(rec_with({})), false)
    eq(io_.front_ok(rec_with({ belt("transport-belt", 4, 0.5, -0.5) })), false)
  end)
  it("behind_empty true without belt behind or with empty lane", function()
    _G.defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
    _G.game = { tick = 0 }
    package.loaded["scripts.belt_io"] = nil
    local io_ = require("scripts.belt_io")
    io_.set_tick(0)
    eq(io_.behind_empty(rec_with({}), 1), true)
    local n = 0
    local b = belt("transport-belt", 0, 0.5, 1.5)
    b.get_transport_line = function() return setmetatable({}, { __len = function() return n end }) end
    local rec = rec_with({ b })
    eq(io_.behind_empty(rec, 1), true)
    n = 3; eq(io_.behind_empty(rec, 1), false)
  end)
end)
