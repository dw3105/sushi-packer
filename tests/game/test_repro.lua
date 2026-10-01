-- FND-0011 repro (author 2026-09-27): 16 EPIC recyclers eat scrap non-stop; outputs merge head-on through a chain of
-- turbo splitters (no side-load) onto one turbo belt, which curves north on the tile behind a north turbo box.
-- Recyclers above belt row 0 face south (drop 0.2 north of centre -> left lane), below row 1 face north (-> right lane).
local N = require("scripts.names")
local belt_io = require("scripts.belt_io")

-- v15 arms box: per-lane state = lane store inventory (rec.invs[lane]).
local function used(rec, lane) return #rec.invs[lane] - rec.invs[lane].count_empty_stacks() end
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
    local box = surface.find_entities_filtered({ position = { 32.5, -0.5 }, name = N.variant("turbo", "north") })[1]
    assert.is_not_nil(box, "box built")
    for _, x in ipairs({ 2, 16, 30 }) do
      surface.create_entity({ name = "substation", position = { x, -9 }, force = force })
      surface.create_entity({ name = "substation", position = { x, 10 }, force = force })
    end
    for _, y in ipairs({ -12, 13 }) do
      local eei = surface.create_entity({ name = "electric-energy-interface", position = { 2, y }, force = force })
      eei.power_production = 1e9; eei.electric_buffer_size = 1e9; eei.energy = 1e9
    end
    for i, r in ipairs(recyclers) do
      assert.is_true(r and r.valid, "recycler " .. i)
      -- author 2026-09-27: belts overloaded -> recyclers drop stacks. Speed modules push supply over turbo 60/s.
      r.get_module_inventory().insert({ name = "speed-module-3", count = 4 })
    end
    local function feed()
      for _, r in ipairs(recyclers) do
        if r.get_item_count("scrap") < 20 then r.insert({ name = "scrap", count = 50 }) end
      end
    end
    local rec = storage.boxes[box.unit_number]
    local real_push, pushes = belt_io.push, { calls = { 0, 0 }, ok = { 0, 0 }, items = { 0, 0 } }
    belt_io.push = function(r, lane, item, bss)
      local n = real_push(r, lane, item, bss)
      pushes.calls[lane] = pushes.calls[lane] + 1
      if n > 0 then pushes.ok[lane] = pushes.ok[lane] + 1; pushes.items[lane] = pushes.items[lane] + n end
      return n
    end
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
        local kinds = {}
        for lane = 1, 2 do
          for _, x in ipairs(rec.invs[lane].get_contents()) do kinds[#kinds + 1] = "L" .. lane .. ":" .. x.name .. "=" .. x.count end
        end
        table.sort(kinds)
        local line = string.format("REPRO t=%d outL=+%d outR=+%d slotsL=%d slotsR=%d itemsL=%d itemsR=%d box=%d led=%s behindL=%d behindR=%d poll=%s stored=%s",
          t, out[1] - last[1], out[2] - last[2], used(rec, 1), used(rec, 2), rec.invs[1].get_item_count(), rec.invs[2].get_item_count(),
          box.get_inventory(defines.inventory.chest).get_item_count(), tostring(rec.led and rec.led.state), behind_lanes[1], behind_lanes[2],
          tostring(rec.next_poll), table.concat(kinds, ","))
        line = line .. string.format(" | push calls %d/%d ok %d/%d items %d/%d",
          pushes.calls[1], pushes.calls[2], pushes.ok[1], pushes.ok[2], pushes.items[1], pushes.items[2])
        pushes = { calls = { 0, 0 }, ok = { 0, 0 }, items = { 0, 0 } }
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
        belt_io.push = real_push
        force.belt_stack_size_bonus = 3; storage.belt_stack = {}
        assert.is_true(l > 0 and r > 0, "last 2 min out L=" .. l .. " R=" .. r)
        done()
        return false
      end
    end)
  end)

  it("author blueprint splitters around turbo box", function()
    -- author 2026-09-27 blueprint ("THIS DOESN'T WORK"): turbo packer north; turbo splitter behind (stone filter),
    -- turbo splitter in front (holmium filter), third splitter bypass east. All output priority right.
    local BP = "0eNqlU9tuwjAM/Rc/pwgKBVpp+5FpQmkJxVoSZ7lMQ6j/PqdFuzJplz5EinN87HPsnqHVSTmPNkJzBuzIBmjuzhCwt1LnmJVGQQMx+ZaK4DTGqDwMAtDu1TM0i+FegLIRI6opd7ycdjaZlpHNQnziSOGIhZPdg/KF07JjkABHgRnI5pLMWpbbWSXgBM1ys5lVXO5JepQTghmj7EOGjmS7iSzfIxpFKe4M7XPFXlPLMsRrnJPmAg6oWUQmYOIOfZdw1K+sbDXnHaQOil/I7nO4I+Okl5G4BNzC+BCizJ7NmeCguYlL0sCf+GJBKb6x8Yru+qJ6PaqeOn03hyNpg8kU5BVnPybJTIwHS96MSj80e5MHxbodS+cpk5/AHvtjhCuNLn/e6HL+YTy/KLL6gxvb626ESPb/PvACY1SGA29/Ay8cb8jYSrUu61VdV9vVesPHMLwAXV8Vgg=="
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 3; storage.belt_stack = {}
    local inv = game.create_inventory(1)
    local stack = inv[1]
    assert.are_equal(0, stack.import_stack(BP), "blueprint imports")
    -- blueprint box at (228.5, 377.5): put it at (0.5, 0.5); splitters keep relative offsets
    local ghosts = stack.build_blueprint({ surface = surface, force = force, position = { 1, 1 }, build_mode = defines.build_mode.forced })
    inv.destroy()
    for _, g in ipairs(ghosts) do if g.valid then g.revive({ raise_revive = true }) end end
    local box = surface.find_entities_filtered({ name = N.variant("turbo", "north") })[1]
    assert.is_not_nil(box, "box built from blueprint")
    local bx, by = box.position.x, box.position.y
    local splitters = surface.find_entities_filtered({ type = "splitter", area = { { bx - 3, by - 3 }, { bx + 3, by + 3 } } })
    assert.are_equal(3, #splitters, "three splitters")
    local report = {}
    for _, sp in ipairs(splitters) do report[#report + 1] = string.format("%s@%.1f,%.1f", sp.name, sp.position.x - bx, sp.position.y - by) end
    -- feed: north belts under splitter behind box (tiles dx=0 and dx=1, dy=+2..+4)
    local function belt(dx, dy) return surface.create_entity({ name = "turbo-transport-belt", position = { bx + dx, by + dy }, direction = D.north, force = force }) end
    local feeds = {}
    for dy = 4, 2, -1 do feeds[#feeds + 1] = belt(0, dy); belt(1, dy) end
    local feed_right = surface.find_entity("turbo-transport-belt", { bx + 1, by + 4 })
    -- outputs: north belts above front splitter (dx=0,1) and bypass splitter right half (dx=2)
    local outs = {}
    for dy = -2, -10, -1 do outs[#outs + 1] = belt(0, dy); belt(1, dy); belt(2, dy - 0 + 1) end
    local kinds = { { "iron-plate", "copper-plate", "stone" }, { "coal", "ice", "holmium-ore" } }
    local rec = storage.boxes[box.unit_number]
    local stacked = { 0, 0 }
    on_tick(function()
      for _, f in ipairs({ feeds[1], feed_right }) do
        for lane = 1, 2 do
          local line = f.get_transport_line(lane)
          if line.can_insert_at_back() then line.insert_at_back({ name = kinds[lane][(game.tick % 3) + 1], count = 1 }) end
        end
      end
      for dx = 0, 2 do
        local top = surface.find_entity("turbo-transport-belt", { bx + dx, by - 10 + (dx == 2 and 1 or 0) })
        if top then for lane = 1, 2 do
          for _, d in ipairs(top.get_transport_line(lane).get_detailed_contents()) do if d.stack.count > 1 then stacked[lane] = stacked[lane] + 1 end end
          top.get_transport_line(lane).clear()
        end end
      end
      if game.tick % 1200 == 0 then
        print(string.format("BP t=%d stacked L=%d R=%d stored=%d/%d used=%d/%d splitters %s", game.tick, stacked[1], stacked[2],
          rec.invs[1].get_item_count(), rec.invs[2].get_item_count(), used(rec, 1), used(rec, 2), table.concat(report, " ")))
      end
      if stacked[1] > 3 and stacked[2] > 3 then return false end
    end)
  end)

  it("author blueprint loaders around west box", function()
    -- author 2026-09-27 blueprint 2: chest -> output loader -> west turbo box -> input loader -> chest (all facing west).
    -- Vanilla loader-1x1 stands in for modded early-stack-size-turbo-loader (not on test VM).
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 3; storage.belt_stack = {}
    local W = D.west
    local src = surface.create_entity({ name = "infinity-chest", position = { 3.5, 0.5 }, force = force })
    for i, item in ipairs({ "iron-plate", "copper-plate", "coal", "stone" }) do
      src.set_infinity_container_filter(i, { name = item, count = 20, mode = "exactly" })
    end
    surface.create_entity({ name = "loader-1x1", position = { 2.5, 0.5 }, direction = W, type = "output", force = force })
    surface.create_entity({ name = N.placer("turbo"), position = { 1.5, 0.5 }, direction = W, force = force, raise_built = true })
    surface.create_entity({ name = "loader-1x1", position = { 0.5, 0.5 }, direction = W, type = "input", force = force })
    local sink = surface.create_entity({ name = "infinity-chest", position = { -0.5, 0.5 }, force = force })
    local box = surface.find_entities_filtered({ name = N.variant("turbo", "west") })[1]
    assert.is_not_nil(box, "west box built")
    local real_push, per_lane, stacked = belt_io.push, { 0, 0 }, 0
    belt_io.push = function(r, lane, item, bss)
      local n = real_push(r, lane, item, bss)
      if n > 0 then per_lane[lane] = per_lane[lane] + n; if n > 1 then stacked = stacked + 1 end end
      return n
    end
    after_ticks(1200, function()
      belt_io.push = real_push
      local got = 0
      for _, x in ipairs(sink.get_inventory(defines.inventory.chest).get_contents()) do got = got + x.count end
      local r = "pushed L=" .. per_lane[1] .. " R=" .. per_lane[2] .. " stacked=" .. stacked .. " sink got=" .. got
      assert.is_true(per_lane[1] > 0 and per_lane[2] > 0, r)
      assert.is_true(stacked > 0, r)
      assert.is_true(got > 0, r)
    end)
  end)
  -- FND-0019 (author 2026-09-28): left output lane congested must not starve right lane. East red box; input belt
  -- left lane iron/copper, right lane coal/stone (script feed); output belt dead end, only right lane drained.
  it("blocked left lane never starves right lane", function()
    async(9000)
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 3; storage.belt_stack = {}
    local B = "fast-transport-belt"
    local function belt(x) return surface.create_entity({ name = B, position = { x + 0.5, 0.5 }, direction = D.east, force = force }) end
    local feed = belt(0)
    for x = 1, 3 do belt(x) end
    surface.create_entity({ name = N.placer("red"), position = { 4.5, 0.5 }, direction = D.east, force = force, raise_built = true })
    local box = surface.find_entities_filtered({ name = N.variant("red", "east") })[1]
    assert.is_not_nil(box, "east box built")
    local last
    for x = 5, 10 do last = belt(x) end
    local left_items, right_items = { "iron-plate", "copper-plate" }, { "coal", "stone" }
    local n, drained, fed = 0, {}, { 0, 0 }
    local start = game.tick
    on_tick(function()
      local t = game.tick - start
      n = n + 1
      for lane, items in ipairs({ left_items, right_items }) do
        local line = feed.get_transport_line(lane)
        if line.can_insert_at_back() and line.insert_at_back({ name = items[n % 2 + 1], count = 1 }) then fed[lane] = fed[lane] + 1 end
      end
      local right = last.get_transport_line(2)
      for _, x in ipairs(right.get_contents()) do drained[#drained + 1] = { t = t, count = x.count } end
      right.clear()
      if t >= 7200 then
        local function window(a, b) local s = 0; for _, d in ipairs(drained) do if d.t >= a and d.t < b then s = s + d.count end end; return s end
        local early, late = window(600, 2400), window(5400, 7200)
        local rec = storage.boxes[box.unit_number]
        local lane_slots = { used(rec, 1), used(rec, 2) }
        local r = string.format("FND-0019 right drained early=%d late=%d fed L=%d R=%d used=%d slotsL=%d slotsR=%d",
          early, late, fed[1], fed[2], lane_slots[1] + lane_slots[2], lane_slots[1], lane_slots[2])
        print(r)
        force.belt_stack_size_bonus = 3; storage.belt_stack = {}
        assert.is_true(early > 0 and late >= 0.8 * early, r)
        -- left lane really was blocked the whole time: its items sit on the dead-end belt and in its lane store only
        assert.are_equal(0, rec.invs[2].get_item_count("iron-plate") + rec.invs[2].get_item_count("copper-plate"), "lanes kept: " .. r)
        assert.are_equal(0, rec.invs[1].get_item_count("coal") + rec.invs[1].get_item_count("stone"), "lanes kept: " .. r)
        done()
        return false
      end
    end)
  end)

  -- FND-0020 (author 2026-09-28): box holds at most one item stack per (item, quality, lane). Iron ore stack 50.
  it("box holds at most one stack per item per lane", function()
    async(4000)
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    force.belt_stack_size_bonus = 3; storage.belt_stack = {}
    local function belt(x) return surface.create_entity({ name = "transport-belt", position = { x + 0.5, 10.5 }, direction = D.east, force = force }) end
    local feed = belt(0); belt(1)
    surface.create_entity({ name = N.placer("yellow"), position = { 2.5, 10.5 }, direction = D.east, force = force, raise_built = true })
    local box = surface.find_entities_filtered({ name = N.variant("yellow", "east") })[1]
    assert.is_not_nil(box, "east box built")
    local cap = prototypes.item["iron-ore"].stack_size
    local start = game.tick
    on_tick(function()
      for lane = 1, 2 do
        local line = feed.get_transport_line(lane)
        if line.can_insert_at_back() then line.insert_at_back({ name = "iron-ore", count = 1 }) end
      end
      if game.tick - start >= 3600 then
        local rec = storage.boxes[box.unit_number]
        -- v15 arms box: per-lane count = lane store inventory; box container takes nothing from the belt.
        local per_lane = { rec.invs[1].get_item_count("iron-ore"), rec.invs[2].get_item_count("iron-ore") }
        local chest = box.get_inventory(defines.inventory.chest).get_item_count("iron-ore")
        local waiting = { 0, 0 }
        for _, b in ipairs(surface.find_entities_filtered({ name = "transport-belt", area = { { 0, 10 }, { 2, 11 } } })) do
          for l = 1, 2 do waiting[l] = waiting[l] + b.get_transport_line(l).get_item_count("iron-ore") end
        end
        local r = string.format("FND-0020 stack=%d chest=%d laneL=%d laneR=%d usedL=%d usedR=%d waitL=%d waitR=%d", cap, chest,
          per_lane[1], per_lane[2], used(rec, 1), used(rec, 2), waiting[1], waiting[2])
        print(r)
        -- C-6 on arms box (V15-3): lane stops taking a kind once it holds one full stack; items already in arm hands
        -- still arrive, so the bound is one stack + arms of lane x hand size, and never more than 2 slots.
        for l = 1, 2 do
          local slack = #rec.arms[l] * N.ARM_HAND
          assert.is_true(per_lane[l] >= cap, "lane " .. l .. " filled one stack before stopping: " .. r)
          assert.is_true(per_lane[l] <= cap + slack, "lane " .. l .. " over one stack + arm hands (" .. slack .. "): " .. r)
        end
        assert.are_equal(0, chest, r)
        assert.is_true(used(rec, 1) <= 2 and used(rec, 2) <= 2, "at most two slots per kind per lane: " .. r)
        assert.is_true(per_lane[1] > 0 and per_lane[2] > 0, "both lanes took items: " .. r)
        assert.is_true(waiting[1] > 0 and waiting[2] > 0, "items over the cap wait on belt: " .. r)
        done()
        return false
      end
    end)
  end)
end)

