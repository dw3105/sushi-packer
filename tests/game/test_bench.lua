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
    local p = positions[1]
    after_ticks(240, function()
      local source = surface.find_entity("infinity-chest", { p.x + 5, p.y })
      assert.is_not_nil(source)
      assert.is_true(source.get_inventory(defines.inventory.chest).get_item_count("iron-plate") > 0, "source has mixed stock")
      local belt = surface.find_entity("transport-belt", { p.x + 1, p.y })
      assert.is_not_nil(belt)
      assert.is_true(next(belt.get_transport_line(1).get_contents()) ~= nil, "first input lane receives items")
      assert.is_true(next(belt.get_transport_line(2).get_contents()) ~= nil, "second input lane receives items")
    end)
  end)
end)
