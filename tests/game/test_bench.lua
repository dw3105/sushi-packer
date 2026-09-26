local builder = require("tests.game.bench_builder")
local N = require("scripts.names")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 40, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("bench", function()
  local surface, force
  before_each(function()
    surface = game.surfaces[1]
    force = game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 0
  end)

  it("builder places requested setups", function()
    local positions = builder.build(surface, force, 3, { 0, 0 })
    assert.are_equal(3, #positions)
    for _, p in ipairs(positions) do
      local box = surface.find_entity(N.variant("yellow", "west"), p) or surface.find_entity(N.placer("yellow"), p)
      assert.is_not_nil(box)
    end
  end)

  it("setup feeds both lanes", function()
    local positions = builder.build(surface, force, 1, { 0, 0 })
    local box_pos = positions[1]
    after_ticks(240, function()
      local input = surface.find_entities_filtered({ position = { box_pos.x + 1, box_pos.y }, type = "transport-belt" })
      assert.are_equal(1, #input)
      local lane1, lane2 = input[1].get_transport_line(1).get_contents(), input[1].get_transport_line(2).get_contents()
      assert.is_true(next(lane1) ~= nil, "left input lane receives items")
      assert.is_true(next(lane2) ~= nil, "right input lane receives items")
    end)
  end)
end)
