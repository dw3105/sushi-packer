defines = { direction = { north = 0, east = 4, south = 8, west = 12 } }
local belt_io = require("scripts.belt_io")

local function find(dir, sign, belts)
  local e = { position = { x = 0, y = 0 }, surface = {
    find_entities_filtered = function(filter)
      local p = filter.position
      local expected = sign == 1 and { x = 0, y = -1 } or { x = 0, y = 1 }
      if p.x == expected.x and p.y == expected.y then return belts end
      return {}
    end,
  } }
  return sign == 1 and belt_io.front(e, dir) or belt_io.behind(e, dir)
end

describe("belt_io", function()
  it("front accepts same direction belt", function()
    ok(find("north", 1, { { valid = true, type = "transport-belt", direction = 0 } }) ~= nil)
  end)
  it("front refuses sideways belt", function()
    eq(find("north", 1, { { valid = true, type = "transport-belt", direction = 4 } }), nil)
  end)
  it("front refuses belt facing box", function()
    eq(find("north", 1, { { valid = true, type = "transport-belt", direction = 8 } }), nil)
  end)
  it("front accepts underground input same direction", function()
    ok(find("north", 1, { { valid = true, type = "underground-belt", belt_to_ground_type = "input", direction = 0 } }) ~= nil)
  end)
  it("behind still requires belt moving into box", function()
    ok(find("north", -1, { { valid = true, type = "transport-belt", direction = 0 } }) ~= nil)
    eq(find("north", -1, { { valid = true, type = "transport-belt", direction = 4 } }), nil)
  end)
end)
