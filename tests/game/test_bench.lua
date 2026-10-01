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
  -- v14 (V14-4, FND-0036): tier + stacks flow built by engine-only merge feed. Test env has no bench mod -> sp-test-loader.
  it("stacks flow feeds stacks 1 to 4 on both lanes", function()
    force.belt_stack_size_bonus = 3
    local positions = builder.build(surface, force, 1, { 0, 0 }, { tier = "red", flow = "stacks", seed = 3, loader = "sp-test-loader" })
    local p = positions[1]
    assert.is_not_nil(surface.find_entity(N.variant("red", "west"), p))
    local input = surface.find_entities_filtered({ position = { p.x + 2, p.y }, name = "fast-transport-belt" })
    assert.are_equal(1, #input)
    local seen, t = { {}, {} }, 0
    on_tick(function()
      t = t + 1
      if t > 300 then
        for lane = 1, 2 do
          for _, d in ipairs(input[1].get_transport_line(lane).get_detailed_contents()) do seen[lane][d.stack.count] = true end
        end
      end
      if t >= 900 then
        for lane = 1, 2 do
          for c = 1, 4 do assert.is_true(seen[lane][c] == true, "lane " .. lane .. " never carried stack of " .. c) end
        end
        local out = surface.find_entities_filtered({ position = { p.x - 2, p.y }, name = "fast-transport-belt" })
        assert.are_equal(1, #out)
        local full = 0
        for lane = 1, 2 do
          for _, d in ipairs(out[1].get_transport_line(lane).get_detailed_contents()) do if d.stack.count == 4 then full = full + 1 end end
        end
        assert.is_true(full > 0, "box output carries 4-stacks")
        return false
      end
    end)
  end)

  it("single flow on fast tier feeds both lanes", function()
    local positions = builder.build(surface, force, 1, { 0, 0 }, { tier = "blue", loader = "sp-test-loader" })
    local p = positions[1]
    after_ticks(240, function()
      local input = surface.find_entities_filtered({ position = { p.x + 1, p.y }, name = "express-transport-belt" })
      assert.are_equal(1, #input)
      assert.is_true(#input[1].get_transport_line(1) > 0, "left input lane receives items")
      assert.is_true(#input[1].get_transport_line(2) > 0, "right input lane receives items")
    end)
  end)
end)
