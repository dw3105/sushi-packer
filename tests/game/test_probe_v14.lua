-- v14 S0 probes (SP-10: NOT in index; temporary entry only). Report via log() + error().
local WEST = defines.direction.west
local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -80, -80 }, { 80, 80 } } })) do if e.valid and e.type ~= "character" then e.destroy() end end
end
describe("probe v14", function()
  it("set facts", function()
    local out = {}
    for _, n in ipairs({ "transport-belt", "express-transport-belt", "turbo-transport-belt", "extreme-belt", "ultimate-belt", "kr-superior-transport-belt", "sp-test-belt-270" }) do
      local p = prototypes.entity[n]; if p then out[#out + 1] = n .. "=" .. p.belt_speed end
    end
    for n, p in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "loader-1x1" }, { filter = "type", type = "loader" } })) do
      out[#out + 1] = "loader " .. n .. "=" .. p.belt_speed
    end
    out[#out + 1] = "max_belt_stack=" .. tostring(prototypes.utility_constants.max_belt_stack_size)
    local f = game.forces.player
    local before = f.belt_stack_size_bonus
    for n, t in pairs(prototypes.technology) do
      for _, e in ipairs(t.effects) do if e.type == "belt-stack-size-bonus" then out[#out + 1] = "tech " .. n .. " +" .. e.modifier end end
    end
    f.research_all_technologies()
    out[#out + 1] = "bonus " .. before .. " -> " .. f.belt_stack_size_bonus
    local mods = {}
    for n, v in pairs(script.active_mods) do mods[#mods + 1] = n .. " " .. v end
    table.sort(mods)
    local text = table.concat(out, "; ") .. " | mods: " .. table.concat(mods, ", ")
    log("v14 probe facts: " .. text)
    error(text)
  end)
  it("loader feed shapes", function()
    -- Rig per variant: infinity chest -> output loader (west) -> 6 belts; last belt tile read + cleared each tick.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local belt = "sp-test-belt-270"
    local names = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit", "coal" }
    local variants = {
      { tag = "atleast-ovr0", override = nil, counts = nil },
      { tag = "atleast-ovr1", override = 1 }, { tag = "atleast-ovr2", override = 2 },
      { tag = "atleast-ovr3", override = 3 }, { tag = "atleast-ovr4", override = 4 },
      { tag = "exact1234-ovr4", override = 4, counts = { 1, 2, 3, 4 } },
      { tag = "exact-b90", override = 4, counts = { 1, 2, 3, 4 }, belt = "sp-test-belt-90" },
      { tag = "exact-b135", override = 4, counts = { 1, 2, 3, 4 }, belt = "sp-test-belt-135" },
      { tag = "exact-turbo", override = 4, counts = { 1, 2, 3, 4 }, belt = "turbo-transport-belt" },
      { tag = "exact-yellow", override = 4, counts = { 3, 1, 4, 2, 2 }, belt = "transport-belt" },
      { tag = "vanilla-loader-yellow", loader = "loader-1x1", belt = "transport-belt" },
    }
    local rigs = {}
    for i, v in ipairs(variants) do
      local y = i * 3
      local chest = surface.create_entity({ name = "infinity-chest", position = { 10.5, y + 0.5 }, force = force })
      local filters = {}
      for slot, name in ipairs(names) do
        if v.counts then
          if v.counts[slot] then filters[#filters + 1] = { index = slot, name = name, count = v.counts[slot], mode = "exactly" } end
        else
          filters[slot] = { index = slot, name = name, count = 1000000, mode = "at-least" }
        end
      end
      chest.infinity_container_filters = filters
      local loader = surface.create_entity({ name = v.loader or "sp-test-loader", position = { 9.5, y + 0.5 }, direction = WEST, force = force, type = "output" })
      local ok, err = true, nil
      if v.override then ok, err = pcall(function() loader.loader_belt_stack_size_override = v.override end) end
      local last
      for x = 8, 3, -1 do last = surface.create_entity({ name = v.belt or belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      rigs[#rigs + 1] = { belt = v.belt or belt, tag = v.tag, last = last, stacks = {}, items = {}, n = { 0, 0 }, set = ok and "ok" or tostring(err), loader = loader }
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.last.get_transport_line(lane)
          if t > 420 then
            for _, d in ipairs(line.get_detailed_contents()) do
              local c = d.stack.count
              r.stacks[c] = (r.stacks[c] or 0) + 1
              r.items[d.stack.name] = (r.items[d.stack.name] or 0) + 1
              r.n[lane] = r.n[lane] + 1
            end
          end
          line.clear()
        end
      end
      if t >= 720 then
        local rep = {}
        for _, r in ipairs(rigs) do
          local want = prototypes.entity[r.belt].belt_speed * 4 * 300
          local s, it = {}, {}
          for c = 1, 20 do if r.stacks[c] then s[#s + 1] = c .. "x" .. r.stacks[c] end end
          for _, name in ipairs(names) do if r.items[name] then it[#it + 1] = name .. ":" .. r.items[name] end end
          rep[#rep + 1] = string.format("%s set=%s ovr_read=%s belt_items L=%d R=%d want=%.0f stacks[%s] items[%s]", r.tag, r.set,
            tostring(r.loader.loader_belt_stack_size_override), r.n[1], r.n[2], want, table.concat(s, " "), table.concat(it, " "))
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe feed: " .. text)
        error(text)
      end
    end)
  end)
  it("prefilled chest feed", function()
    -- Chest slots prefilled with (item, count 1..4); loader override 4. Does belt stack = slot count, in slot order?
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local seq = { { "iron-plate", 1 }, { "copper-plate", 2 }, { "iron-plate", 3 }, { "iron-plate", 2 }, { "coal", 4 }, { "copper-plate", 1 },
      { "copper-plate", 3 }, { "iron-gear-wheel", 2 }, { "coal", 1 }, { "iron-plate", 4 }, { "iron-plate", 1 }, { "electronic-circuit", 3 } }
    local rigs = {}
    for i, belt in ipairs({ "transport-belt", "turbo-transport-belt", "sp-test-belt-270" }) do
      local y = i * 3
      local chest = surface.create_entity({ name = "steel-chest", position = { 10.5, y + 0.5 }, force = force })
      local inv = chest.get_inventory(defines.inventory.chest)
      for slot = 1, 48 do local e = seq[(slot - 1) % #seq + 1]; inv[slot].set_stack({ name = e[1], count = e[2] }) end
      local loader = surface.create_entity({ name = "sp-test-loader", position = { 9.5, y + 0.5 }, direction = WEST, force = force, type = "output" })
      loader.loader_belt_stack_size_override = 4
      local last
      for x = 8, 3, -1 do last = surface.create_entity({ name = belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      rigs[#rigs + 1] = { belt = belt, last = last, got = { {}, {} }, chest = chest }
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.last.get_transport_line(lane)
          for _, d in ipairs(line.get_detailed_contents()) do r.got[lane][#r.got[lane] + 1] = d.stack.name:sub(1, 2) .. d.stack.count end
          line.clear()
        end
      end
      if t >= 900 then
        local rep = {}
        for _, r in ipairs(rigs) do
          rep[#rep + 1] = r.belt .. " left_in_chest=" .. r.chest.get_inventory(defines.inventory.chest).get_item_count() .. " L[" .. table.concat(r.got[1], " ") .. "] R[" .. table.concat(r.got[2], " ") .. "]"
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe prefill: " .. text)
        error(text)
      end
    end)
  end)
  it("splitter merge feed", function()
    -- 4 infinity chests -> 4 loaders (override 1..4, own item each) -> 2 splitters -> 1 splitter -> belt. Engine only.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local items = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit" }
    local rigs = {}
    for i, pair in ipairs({ { "transport-belt", "splitter" }, { "turbo-transport-belt", "turbo-splitter" } }) do
      local belt, split = pair[1], pair[2]
      local y = i * 8
      for k = 1, 4 do
        local chest = surface.create_entity({ name = "infinity-chest", position = { 13.5, y + k - 0.5 }, force = force })
        chest.infinity_container_filters = { { index = 1, name = items[k], count = 1000, mode = "at-least" } }
        local loader = surface.create_entity({ name = "sp-test-loader", position = { 12.5, y + k - 0.5 }, direction = WEST, force = force, type = "output" })
        loader.loader_belt_stack_size_override = k
      end
      surface.create_entity({ name = split, position = { 11.5, y + 1 }, direction = WEST, force = force })
      surface.create_entity({ name = split, position = { 11.5, y + 3 }, direction = WEST, force = force })
      surface.create_entity({ name = belt, position = { 10.5, y + 1.5 }, direction = WEST, force = force })
      surface.create_entity({ name = belt, position = { 10.5, y + 2.5 }, direction = WEST, force = force })
      surface.create_entity({ name = split, position = { 9.5, y + 2 }, direction = WEST, force = force })
      local last
      for x = 8, 3, -1 do last = surface.create_entity({ name = belt, position = { x + 0.5, y + 1.5 }, direction = WEST, force = force }) end
      rigs[#rigs + 1] = { belt = belt, last = last, got = { {}, {} }, hist = {}, n = { 0, 0 } }
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.last.get_transport_line(lane)
          if t > 600 then
            for _, d in ipairs(line.get_detailed_contents()) do
              r.n[lane] = r.n[lane] + 1
              r.hist[d.stack.count] = (r.hist[d.stack.count] or 0) + 1
              if #r.got[lane] < 24 then r.got[lane][#r.got[lane] + 1] = d.stack.name:sub(1, 6) .. d.stack.count end
            end
          end
          line.clear()
        end
      end
      if t >= 1200 then
        local rep = {}
        for _, r in ipairs(rigs) do
          local h = {}
          for c = 1, 4 do h[#h + 1] = c .. "x" .. (r.hist[c] or 0) end
          rep[#rep + 1] = string.format("%s belt_items L=%d R=%d want=%.0f hist[%s] L[%s] R[%s]", r.belt, r.n[1], r.n[2],
            prototypes.entity[r.belt].belt_speed * 4 * 600, table.concat(h, " "), table.concat(r.got[1], " "), table.concat(r.got[2], " "))
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe merge: " .. text)
        error(text)
      end
    end)
  end)
  it("can_insert_at vs front item position", function()
    -- rung 1 helper: can a few can_insert_at(q) calls replace get_detailed_contents for "front item within x of end"?
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    local belt = surface.create_entity({ name = "turbo-transport-belt", position = { 0.5, 0.5 }, direction = WEST, force = force })
    local line = belt.get_transport_line(1)
    local rep = {}
    for _, x in ipairs({ 0, 0.03, 0.0625, 0.1, 0.125, 0.2, 0.25, 0.3, 0.5 }) do
      line.clear()
      local ok = line.insert_at(x, { name = "iron-plate", count = 1 })
      local d = line.get_detailed_contents()
      local row = {}
      for _, q in ipairs({ 0, 0.03, 0.0625, 0.1, 0.125, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.75 }) do row[#row + 1] = line.can_insert_at(q) and "1" or "0" end
      rep[#rep + 1] = string.format("x=%.4f ins=%s pos=%s can[%s]", x, tostring(ok), d[1] and string.format("%.4f", d[1].position) or "-", table.concat(row))
    end
    rep[#rep + 1] = "line_length=" .. tostring(line.line_length)
    local text = table.concat(rep, " ;; ")
    log("v14 probe caninsert: " .. text)
    error(text)
  end)
  it("r2 loader pair on one tile", function()
    -- rung 2: belt -> in-loader -> chest (same tile) -> out-loader (waits for full stacks) -> belt. Zero script.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local rigs = {}
    for i, v in ipairs({ { belt = "transport-belt", out = "sp-test-r2-out" }, { belt = "turbo-transport-belt", out = "sp-test-r2-out" }, { belt = "turbo-transport-belt", out = "sp-test-r2-out-lanes" } }) do
      local y = i * 6
      -- feed: lane-distinct items so lane mixing shows: left lane iron (stacks of 1) + copper (2); right lane gears (3) + circuits (1)
      for x = 12, 7, -1 do surface.create_entity({ name = v.belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      local errs = {}
      local function mk(spec) local ok, e = pcall(surface.create_entity, spec); if not ok then errs[#errs + 1] = tostring(e) end; return ok and e or nil end
      local chest = mk({ name = "sp-test-r2-chest", position = { 6.5, y + 0.5 }, force = force })
      local lin = mk({ name = "sp-test-r2-in", position = { 6.5, y + 0.5 }, direction = WEST, force = force, type = "input" })
      local lout = mk({ name = v.out, position = { 6.5, y + 0.5 }, direction = WEST, force = force, type = "output" })
      local outb
      for x = 5, 0, -1 do outb = surface.create_entity({ name = v.belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      rigs[#rigs + 1] = { tag = v.belt .. "/" .. v.out, feed = surface.find_entity(v.belt, { 12.5, y + 0.5 }), last = outb, chest = chest, lin = lin, lout = lout, errs = errs,
        got = { {}, {} }, n = { 0, 0 }, hist = {}, fed = { 0, 0 } }
    end
    local t = 0
    local left, right = { { "iron-plate", 1 }, { "copper-plate", 2 } }, { { "iron-gear-wheel", 3 }, { "electronic-circuit", 1 } }
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local src = lane == 1 and left or right
          local k = 0
          while k < 4 and line.can_insert_at_back() do
            r.fed[lane] = r.fed[lane] + 1; k = k + 1
            local e = src[r.fed[lane] % 2 + 1]
            line.insert_at_back({ name = e[1], count = e[2] }, e[2])
          end
          local out = r.last.get_transport_line(lane)
          if t > 600 then
            for _, d in ipairs(out.get_detailed_contents()) do
              r.n[lane] = r.n[lane] + 1
              local key = d.stack.name:sub(1, 6) .. d.stack.count
              r.got[lane][key] = (r.got[lane][key] or 0) + 1
            end
          end
          out.clear()
        end
      end
      if t >= 1200 then
        local rep = {}
        for _, r in ipairs(rigs) do
          local function show(m) local o = {}; for k, c in pairs(m) do o[#o + 1] = k .. "x" .. c end; table.sort(o); return table.concat(o, " ") end
          local inv = r.chest and r.chest.valid and r.chest.get_inventory(defines.inventory.chest)
          local cont = {}
          if inv then for _, c in ipairs(inv.get_contents()) do cont[#cont + 1] = c.name:sub(1, 6) .. c.count end end
          rep[#rep + 1] = string.format("%s errs[%s] in=%s out=%s incont=%s outcont=%s belt_items_out L=%d R=%d want=%.0f L[%s] R[%s] chest[%s] feed_back L=%d R=%d",
            r.tag, table.concat(r.errs, "|"), tostring(r.lin and r.lin.valid), tostring(r.lout and r.lout.valid),
            tostring(r.lin and r.lin.valid and r.lin.loader_container and r.lin.loader_container.name), tostring(r.lout and r.lout.valid and r.lout.loader_container and r.lout.loader_container.name),
            r.n[1], r.n[2], prototypes.entity[r.last.name].belt_speed * 4 * 600, show(r.got[1]), show(r.got[2]), table.concat(cont, " "), r.fed[1], r.fed[2])
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe r2pair: " .. text)
        error(text)
      end
    end)
  end)
  it("r2 engine input into box chest", function()
    -- rung 2 candidate G: belt -> in-loader (box tile) -> chest on same tile. Rate per lane, stop by script, chest full.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local rigs = {}
    for i, v in ipairs({ { belt = "transport-belt" }, { belt = "turbo-transport-belt" }, { belt = "sp-test-belt-270" }, { belt = "turbo-transport-belt", stop = "active" }, { belt = "turbo-transport-belt", stop = "disabled_by_script" }, { belt = "turbo-transport-belt", stacks = true } }) do
      local y = i * 4
      for x = 12, 7, -1 do surface.create_entity({ name = v.belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      local chest = surface.create_entity({ name = "sp-test-r2-chest", position = { 6.5, y + 0.5 }, force = force })
      local lin = surface.create_entity({ name = "sp-test-r2-in", position = { 6.5, y + 0.5 }, direction = WEST, force = force, type = "input" })
      rigs[#rigs + 1] = { v = v, feed = surface.find_entity(v.belt, { 12.5, y + 0.5 }), chest = chest, lin = lin, fed = { 0, 0 }, at600 = 0, at900 = 0, note = "" }
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        local inv = r.chest.get_inventory(defines.inventory.chest)
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local k = 0
          while k < 4 and line.can_insert_at_back() do
            k = k + 1; r.fed[lane] = r.fed[lane] + 1
            local c = r.v.stacks and (r.fed[lane] % 4 + 1) or 1
            line.insert_at_back({ name = lane == 1 and "iron-plate" or "copper-plate", count = c }, c)
          end
        end
        if t % 30 == 0 and not r.v.full then inv.clear() end  -- keep chest empty: measure pure rate
        if t == 600 then r.fed600 = { r.fed[1], r.fed[2] } end
        if t == 900 then
          r.fed900 = { r.fed[1], r.fed[2] }
          if r.v.stop == "active" then local ok, e = pcall(function() r.lin.active = false end); r.note = "set=" .. tostring(ok) .. " " .. tostring(not ok and e or r.lin.active) end
          if r.v.stop == "disabled_by_script" then local ok, e = pcall(function() r.lin.disabled_by_script = true end); r.note = "set=" .. tostring(ok) .. " read=" .. tostring(r.lin.disabled_by_script) end
        end
      end
      if t >= 1200 then
        local rep = {}
        for _, r in ipairs(rigs) do
          local want = prototypes.entity[r.feed.name].belt_speed * 4 * 300
          rep[#rep + 1] = string.format("%s%s%s belt_items 600-900 L=%d R=%d want=%.0f | 900-1200 L=%d R=%d %s", r.feed.name, r.v.stop and ("/stop:" .. r.v.stop) or "", r.v.stacks and "/stacks" or "",
            r.fed900[1] - r.fed600[1], r.fed900[2] - r.fed600[2], want, r.fed[1] - r.fed900[1], r.fed[2] - r.fed900[2], r.note)
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe r2in: " .. text)
        error(text)
      end
    end)
  end)
  it("arms lane lock and rate", function()
    -- Way A: belt dead-ends at box tile; n hidden arms per lane, each locked to one lane, each told its own pot.
    -- Left lane fed iron, right lane copper: any copper in left pot = lane leak.
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    force.belt_stack_size_bonus = 3
    local rigs = {}
    local variants = {
      { belt = "transport-belt", n = 1 }, { belt = "turbo-transport-belt", n = 1 }, { belt = "turbo-transport-belt", n = 2 },
      { belt = "turbo-transport-belt", n = 4 }, { belt = "sp-test-belt-270", n = 2 }, { belt = "sp-test-belt-270", n = 4 },
      { belt = "sp-test-belt-270", n = 8 }, { belt = "turbo-transport-belt", n = 1, stack = 4 }, { belt = "turbo-transport-belt", n = 2, stack = 4 },
      { belt = "sp-test-belt-270", n = 4, stack = 4 },
    }
    for i, v in ipairs(variants) do
      local y = i * 4
      for x = 12, 7, -1 do surface.create_entity({ name = v.belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }) end
      local pots, notes = {}, {}
      for lane = 1, 2 do pots[lane] = surface.create_entity({ name = "sp-test-r2-chest", position = { 6.5, y + 0.5 }, force = force }) end
      local arms = 0
      for lane = 1, 2 do
        for k = 1, v.n do
          local arm = surface.create_entity({ name = "sp-test-arm", position = { 6.5, y + 0.5 }, direction = WEST, force = force })
          if arm then
            arms = arms + 1
            local function try(tag, f) local ok, e = pcall(f); if not ok then notes[tag] = tostring(e):sub(1, 80) end end
            try("pickup_position", function() arm.pickup_position = { 7.5, y + 0.5 } end)
            try("drop_position", function() arm.drop_position = { 6.5, y + 0.5 } end)
            try("lane", function() arm.pickup_from_left_lane = lane == 1; arm.pickup_from_right_lane = lane == 2 end)
            try("drop_target", function() arm.drop_target = pots[lane] end)
          end
        end
      end
      rigs[#rigs + 1] = { v = v, feed = surface.find_entity(v.belt, { 12.5, y + 0.5 }), pots = pots, arms = arms, notes = notes, fed = { 0, 0 }, got = { {}, {} } }
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        local c = r.v.stack or 1
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local k = 0
          while k < 4 and line.can_insert_at_back() do
            k = k + 1
            if t > 600 then r.fed[lane] = r.fed[lane] + c end
            line.insert_at_back({ name = lane == 1 and "iron-plate" or "copper-plate", count = c }, c)
          end
          if t % 20 == 0 then
            local inv = r.pots[lane].get_inventory(defines.inventory.chest)
            if t > 600 then for _, x in ipairs(inv.get_contents()) do r.got[lane][x.name] = (r.got[lane][x.name] or 0) + x.count end end
            inv.clear()
          end
        end
      end
      if t >= 1200 then
        local rep = {}
        for _, r in ipairs(rigs) do
          local want = prototypes.entity[r.feed.name].belt_speed * 4 * 600 * (r.v.stack or 1)
          local n = {}
          for k, e in pairs(r.notes) do n[#n + 1] = k .. ":" .. e end
          rep[#rep + 1] = string.format("%s n=%d stack=%d arms=%d | fed L=%d R=%d want=%.0f | potL iron=%d copper=%d | potR iron=%d copper=%d | %s",
            r.feed.name, r.v.n, r.v.stack or 1, r.arms, r.fed[1], r.fed[2], want,
            r.got[1]["iron-plate"] or 0, r.got[1]["copper-plate"] or 0, r.got[2]["iron-plate"] or 0, r.got[2]["copper-plate"] or 0, table.concat(n, " "))
        end
        local text = table.concat(rep, " ;; ")
        log("v14 probe arms: " .. text)
        error(text)
      end
    end)
  end)
end)
