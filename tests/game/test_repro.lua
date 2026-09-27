-- FND-0011 repro (author 2026-09-27): 16 EPIC recyclers eat scrap non-stop; outputs merge head-on through a chain of
-- turbo splitters (no side-load) onto one turbo belt, which curves north on the tile behind a north turbo box.
-- Recyclers above belt row 0 face south (drop 0.2 north of centre -> left lane), below row 1 face north (-> right lane).
local N = require("scripts.names")
local D = defines.direction

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -40, -40 }, { 60, 40 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("repro", function()
  it("sixteen scrap recyclers feed north turbo box", function()
    async(40000)
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 19  -- author save: belt stack 20 (test env mod raises engine max to 20)
    force.recipes["scrap-recycling"].enabled = true  -- test world has no research; author map has it
    storage.belt_stack = {}
    local function belt(x, y, dir) return surface.create_entity({ name = "turbo-transport-belt", position = { x + 0.5, y + 0.5 }, direction = dir, force = force }) end
    local recyclers = {}
    for k = 0, 7 do
      for x = 4 * k - 3, 4 * k - 1 do belt(x, 0, D.east); belt(x, 1, D.east) end
      surface.create_entity({ name = "turbo-splitter", position = { 4 * k + 0.5, 1 }, direction = D.east, force = force })
      local cx = 4 * k - 2
      recyclers[#recyclers + 1] = surface.create_entity({ name = "recycler", position = { cx, -2 }, direction = D.south, force = force, quality = "epic" })
      recyclers[#recyclers + 1] = surface.create_entity({ name = "recycler", position = { cx, 4 }, direction = D.north, force = force, quality = "epic" })
    end
    for x = 29, 31 do belt(x, 0, D.east) end
    belt(32, 0, D.north)  -- curve: feed from west turns north behind box (author layout)
    local front = {}
    for y = -2, -13, -1 do front[#front + 1] = belt(32, y, D.north) end
    surface.create_entity({ name = "loader-1x1", position = { 32.5, -13.5 }, direction = D.north, force = force, type = "input" })
    local sink = surface.create_entity({ name = "infinity-chest", position = { 32.5, -14.5 }, force = force })
    sink.remove_unfiltered_items = true
    surface.create_entity({ name = N.placer("turbo"), position = { 32.5, -0.5 }, direction = D.north, force = force, raise_built = true })
    local box = surface.find_entities_filtered({ position = { 32.5, -0.5 }, type = "container" })[1]
    assert.is_not_nil(box, "box built")
    for _, x in ipairs({ 2, 16, 30 }) do
      surface.create_entity({ name = "substation", position = { x, -9 }, force = force })
      surface.create_entity({ name = "substation", position = { x, 10 }, force = force })
    end
    for _, y in ipairs({ -12, 13 }) do
      local eei = surface.create_entity({ name = "electric-energy-interface", position = { 2, y }, force = force })
      eei.power_production = 1e9; eei.electric_buffer_size = 1e9; eei.energy = 1e9
    end
    for i, r in ipairs(recyclers) do assert.is_true(r and r.valid, "recycler " .. i) end
    local function feed()
      for _, r in ipairs(recyclers) do
        if r.get_item_count("scrap") < 20 then r.insert({ name = "scrap", count = 50 }) end
      end
    end
    local rec = storage.boxes[box.unit_number]
    local watch = front[#front - 1]  -- tile before loader: count items leaving per lane by unique_id
    local seen, out = { {}, {} }, { 0, 0 }
    local windows, last, start = {}, { 0, 0 }, game.tick
    local behind = surface.find_entity("turbo-transport-belt", { 32.5, 0.5 })
    local behind_lanes = { 0, 0 }
    local LIMIT = 36000
    on_tick(function()
      feed()
      for lane = 1, 2 do
        for _, d in ipairs(watch.get_transport_line(lane).get_detailed_contents()) do
          if not seen[lane][d.unique_id] then seen[lane][d.unique_id] = true; out[lane] = out[lane] + d.stack.count end
        end
        if #behind.get_transport_line(lane) > 0 then behind_lanes[lane] = behind_lanes[lane] + 1 end
      end
      local t = game.tick - start
      if t % 600 == 0 and t > 0 then
        local b = rec.box
        local pl = { 0, 0 }
        for _, p in ipairs(b.partials) do pl[p.lane] = pl[p.lane] + 1 end
        local kinds = {}
        for _, x in ipairs(box.get_inventory(defines.inventory.chest).get_contents()) do kinds[#kinds + 1] = x.name .. "=" .. x.count end
        table.sort(kinds)
        local line = string.format("REPRO t=%d outL=+%d outR=+%d used=%d partialsL=%d partialsR=%d readyL=%d readyR=%d holdL=%s holdR=%s behindL=%d behindR=%d poll=%s stored=%s",
          t, out[1] - last[1], out[2] - last[2], b.used_slots, pl[1], pl[2], #b.ready[1], #b.ready[2],
          tostring(b.hold[1] and b.hold[1].name), tostring(b.hold[2] and b.hold[2].name), behind_lanes[1], behind_lanes[2],
          tostring(rec.next_poll), table.concat(kinds, ","))
        print(line)
        if t == 600 then
          local r1 = recyclers[1]
          print(string.format("REPRO recycler1 status=%s recipe=%s done=%d q=%s", tostring(r1.status),
            tostring(r1.get_recipe() and r1.get_recipe().name), r1.products_finished, r1.quality.name))
        end
        windows[#windows + 1] = { out[1] - last[1], out[2] - last[2] }
        last = { out[1], out[2] }
        behind_lanes = { 0, 0 }
        for i = 1, 16 do seen[1][i] = nil end
      end
      if t >= LIMIT then
        local l, r = 0, 0
        for i = #windows - 11, #windows do l = l + windows[i][1]; r = r + windows[i][2] end
        force.belt_stack_size_bonus = 3; storage.belt_stack = {}
        assert.is_true(l > 0 and r > 0, "last 2 min out L=" .. l .. " R=" .. r)
        done()
        return false
      end
    end)
  end)
end)
