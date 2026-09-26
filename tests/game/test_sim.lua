-- U-8: simulation scene builder runs real box logic (scene look = author eyes).
local N = require("scripts.names")
local sim = require("scripts.sim")

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("sim", function()
  it("scene makes stacked output", function()
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    sim.scene("factoriopedia")
    local box = surface.find_entities_filtered({ name = N.variant("yellow", "east") })[1]
    assert.is_not_nil(box, "box built east")
    assert.is_not_nil(storage.boxes[box.unit_number], "box registered")
    after_ticks(900, function()
      local stacked, mixed_in_one = 0, 0
      for x = 1, 3 do
        local belt = surface.find_entity("transport-belt", { x + 0.5, 0.5 })
        for lane = 1, 2 do
          for _, d in ipairs(belt.get_transport_line(lane).get_detailed_contents()) do
            if d.stack.count == 4 then stacked = stacked + 1 end
          end
        end
      end
      local seen = surface.find_entities_filtered({ name = "infinity-chest" })
      local rec = storage.boxes[box.unit_number]
      local info = " in_box=" .. tostring(rec and rec.box.stored_count)
      force.belt_stack_size_bonus = 0
      assert.is_true(stacked > 0, "out belt carries 4-stacks, found " .. stacked .. " chests " .. #seen .. info)
    end)
  end)
end)
