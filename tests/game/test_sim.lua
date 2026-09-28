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
    -- U-8 v1.4 (author layout: box centered, machinery off frame): inserters drop coal + circuit on left lane, iron + copper on right; box packs 4-stacks.
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
      for x = -11, -1 do
        local belt = surface.find_entity("transport-belt", { x + 0.5, 0.5 })
        for lane = 1, 2 do
          for _, d in ipairs(belt.get_transport_line(lane).get_detailed_contents()) do inkinds[lane][d.stack.name] = true end
        end
      end
      for x = 1, 11 do
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
  it("scene built by console in fresh game outputs", function()
    -- author 2026-09-28 thumbnail shots: fresh Freeplay, console line (clear area, grass, scene) -> output belt empty.
    async(3000)
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 0
    storage.belt_stack = {}
    local t = {}
    for x = -22, 17 do for y = -14, 7 do t[#t + 1] = { name = "grass-1", position = { x, y } } end end
    surface.set_tiles(t)
    after_ticks(120, function()  -- fresh game: belt stack cached before scene raises bonus
      remote.call(N.SIM_INTERFACE, "scene", "factoriopedia")
      local box = surface.find_entities_filtered({ name = N.variant("yellow", "east") })[1]
      assert.is_not_nil(box, "box built east")
      local start, out = game.tick, 0
      on_tick(function()
        if game.tick - start < 1800 then return end
        for x = 1, 11 do
          local belt = surface.find_entity("transport-belt", { x + 0.5, 0.5 })
          for lane = 1, 2 do out = out + #belt.get_transport_line(lane) end
        end
        local rec = storage.boxes[box.unit_number]
        local r = string.format("out belt items=%d stored=%d bss=%s ready=%d/%d partials=%d", out, rec.box.stored_count,
          tostring(storage.belt_stack[force.index]), #rec.box.ready[1], #rec.box.ready[2], #rec.box.partials)
        force.belt_stack_size_bonus = 0; storage.belt_stack = {}
        assert.is_true(out > 0, r)
        done()
        return false
      end)
    end)
  end)
  it("scene never stalls", function()
    -- FND-0013: author 2026-09-27 saw yellow box stutter in scene; item must never rest at belt end behind box.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    sim.scene("tips")
    local behind = surface.find_entity("transport-belt", { -0.5, 0.5 })
    local run, max, seen, start = { 0, 0 }, 0, 0, game.tick
    on_tick(function()
      for lane = 1, 2 do
        local line = behind.get_transport_line(lane)
        if #line > 0 then seen = seen + 1 end
        if #line > 0 and not line.can_insert_at(0) then
          run[lane] = run[lane] + 1
          if run[lane] > max then max = run[lane] end
        else
          run[lane] = 0
        end
      end
      if game.tick - start >= 1500 then
        force.belt_stack_size_bonus = 0
        assert.is_true(seen > 0, "items reached box")
        assert.is_true(max <= 2, "item rested at exit " .. max .. " ticks")
        return false
      end
    end)
  end)
end)
