-- U-8: simulation scene builder runs real box logic (scene look = author eyes).
local N = require("scripts.names")
local sim = require("scripts.sim")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("sim", function()
  it("scene feeds both lanes with four kinds", function()
    -- U-8 v1.3 (author layout): inserters drop coal + circuit on left lane, iron + copper on right; box packs 4-stacks.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    sim.scene("factoriopedia")
    local box = surface.find_entities_filtered({ name = N.variant("yellow", "east") })[1]
    assert.is_not_nil(box, "box built east")
    assert.is_not_nil(storage.boxes[box.unit_number], "box registered")
    after_ticks(1500, function()
      local inkinds, outstacks = { {}, {} }, { 0, 0 }
      local outkinds = { {}, {} }
      for x = -5, -1 do
        local belt = surface.find_entity("transport-belt", { x + 0.5, 0.5 })
        for lane = 1, 2 do
          for _, d in ipairs(belt.get_transport_line(lane).get_detailed_contents()) do inkinds[lane][d.stack.name] = true end
        end
      end
      for x = 1, 3 do
        local belt = surface.find_entity("transport-belt", { x + 0.5, 0.5 })
        for lane = 1, 2 do
          for _, d in ipairs(belt.get_transport_line(lane).get_detailed_contents()) do
            if d.stack.count == 4 then outstacks[lane] = outstacks[lane] + 1 end
            outkinds[lane][d.stack.name] = true
          end
        end
      end
      local function keys(t) local k = {} for n in pairs(t) do k[#k + 1] = n end table.sort(k) return table.concat(k, ",") end
      local r = "in L=" .. keys(inkinds[1]) .. " R=" .. keys(inkinds[2]) .. " out L=" .. keys(outkinds[1]) .. " R=" .. keys(outkinds[2]) ..
        " stacks L=" .. outstacks[1] .. " R=" .. outstacks[2]
      force.belt_stack_size_bonus = 0
      for n in pairs(inkinds[1]) do assert.is_true(n == "coal" or n == "electronic-circuit", r) end
      for n in pairs(inkinds[2]) do assert.is_true(n == "iron-plate" or n == "copper-plate", r) end
      assert.is_true(outstacks[1] > 0 and outstacks[2] > 0, r)
    end)
  end)
end)
