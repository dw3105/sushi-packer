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
end)
