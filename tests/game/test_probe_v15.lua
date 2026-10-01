-- v15 S0 probes for arms box (SP-10: NOT in index; temporary entry only). Report via log() + error().
local WEST, NORTH = defines.direction.west, defines.direction.north
local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -90, -90 }, { 90, 200 } } })) do if e.valid and e.type ~= "character" then e.destroy() end end
end
local KINDS = { "iron-plate", "copper-plate", "iron-gear-wheel", "electronic-circuit" }
-- box tile (bx, y): n arms per lane taking from (px, py), two stores. Returns stores, arms.
local function box(surface, force, bx, by, px, py, n, arm)
  local stores, arms = {}, { {}, {} }
  for lane = 1, 2 do stores[lane] = surface.create_entity({ name = "sp-test-r2-chest", position = { bx, by }, force = force }) end
  for lane = 1, 2 do
    for k = 1, n do
      local a = surface.create_entity({ name = arm or "sp-test-arm", position = { bx, by }, direction = WEST, force = force })
      a.pickup_position = { px, py }; a.drop_position = { bx, by }
      a.pickup_from_left_lane = lane == 1; a.pickup_from_right_lane = lane == 2
      a.drop_target = stores[lane]
      arms[lane][k] = a
    end
  end
  return stores, arms
end
local function count(store, name) return store.get_inventory(defines.inventory.chest).get_item_count(name) end
describe("probe v15", function()
  it("arms per speed worst mix", function()
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    local rigs, row = {}, 0
    for _, belt in ipairs({ "transport-belt", "fast-transport-belt", "express-transport-belt", "turbo-transport-belt", "sp-test-belt-135", "sp-test-belt-270" }) do
      for _, n in ipairs({ 1, 2, 4, 8, 12 }) do
        row = row + 1
        local y = row * 3
        local feed
        for x = 12, 7, -1 do local b = surface.create_entity({ name = belt, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }); feed = feed or b end
        local stores = box(surface, force, 6.5, y + 0.5, 7.5, y + 0.5, n)
        rigs[#rigs + 1] = { belt = belt, n = n, feed = feed, stores = stores, fed = { 0, 0 }, k = { 0, 0 } }
      end
    end
    local t = 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local tries = 0
          while tries < 4 and line.can_insert_at_back() do
            tries = tries + 1; r.k[lane] = r.k[lane] + 1
            if t > 600 then r.fed[lane] = r.fed[lane] + 1 end
            line.insert_at_back({ name = KINDS[(r.k[lane] + lane) % 4 + 1], count = 1 })
          end
          if t % 20 == 0 then r.stores[lane].get_inventory(defines.inventory.chest).clear() end
        end
      end
      if t >= 1200 then
        local rep, cur = {}, nil
        for _, r in ipairs(rigs) do
          local want = prototypes.entity[r.belt].belt_speed * 4 * 600
          if cur ~= r.belt then cur = r.belt; rep[#rep + 1] = "\n" .. r.belt .. " want=" .. string.format("%.0f", want) .. ":" end
          rep[#rep + 1] = string.format(" n%d=%d/%d", r.n, r.fed[1], r.fed[2])
        end
        local text = table.concat(rep)
        log("v15 probe arms-speed: " .. text)
        error(text)
      end
    end)
  end)
  it("skip kind pause wires behind kinds", function()
    local surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    local out, notes = {}, {}
    local function try(tag, f) local ok, e = pcall(f); if not ok then notes[#notes + 1] = tag .. ":" .. tostring(e):sub(1, 90) end; return ok end
    local function belts(name, y, x1, x2) local first; for x = x1, x2, -1 do local b = surface.create_entity({ name = name, position = { x + 0.5, y + 0.5 }, direction = WEST, force = force }); first = first or b end; return first end
    -- A skip kind: lane L iron/copper alternating, arms L blacklist iron -> copper only, then lane stalls on iron
    local feedA = belts("turbo-transport-belt", 3, 12, 7)
    local storesA, armsA = box(surface, force, 6.5, 3.5, 7.5, 3.5, 4, "sp-test-arm-f")
    for _, a in ipairs(armsA[1]) do
      try("use_filters", function() a.use_filters = true end)
      try("filter_mode", function() a.inserter_filter_mode = "blacklist" end)
      try("set_filter", function() a.set_filter(1, { name = "iron-plate" }) end)
    end
    -- B pause: arms disabled_by_script at t=600
    local feedB = belts("turbo-transport-belt", 9, 12, 7)
    local storesB, armsB = box(surface, force, 6.5, 9.5, 7.5, 9.5, 4)
    -- C behind = splitter (west), box on its upper output tile
    belts("turbo-transport-belt", 14, 14, 9); belts("turbo-transport-belt", 15, 14, 9)
    local feedC1, feedC2 = surface.find_entity("turbo-transport-belt", { 14.5, 14.5 }), surface.find_entity("turbo-transport-belt", { 14.5, 15.5 })
    surface.create_entity({ name = "turbo-splitter", position = { 8.5, 15 }, direction = WEST, force = force })
    local storesC = box(surface, force, 7.5, 14.5, 8.5, 14.5, 4)
    belts("turbo-transport-belt", 15, 7, 2)  -- lower output keeps flowing away
    -- D behind = underground exit
    local feedD = belts("turbo-transport-belt", 20, 16, 13)
    surface.create_entity({ name = "turbo-underground-belt", position = { 12.5, 20.5 }, direction = WEST, force = force, type = "input" })
    surface.create_entity({ name = "turbo-underground-belt", position = { 8.5, 20.5 }, direction = WEST, force = force, type = "output" })
    local storesD = box(surface, force, 7.5, 20.5, 8.5, 20.5, 4)
    -- E behind = 1x1 loader output from chest (iron only: loader lane split shows in stores)
    local src = surface.create_entity({ name = "infinity-chest", position = { 9.5, 25.5 }, force = force })
    src.infinity_container_filters = { { index = 1, name = "iron-plate", count = 1000, mode = "at-least" } }
    surface.create_entity({ name = "sp-test-loader", position = { 8.5, 25.5 }, direction = WEST, force = force, type = "output" })
    local storesE = box(surface, force, 7.5, 25.5, 8.5, 25.5, 4)
    -- F north-facing rig: belt runs north into box
    local feedF
    for yy = 40, 35, -1 do local b = surface.create_entity({ name = "turbo-transport-belt", position = { 20.5, yy + 0.5 }, direction = NORTH, force = force }); feedF = feedF or b end
    local storesF = box(surface, force, 20.5, 34.5, 20.5, 35.5, 4)
    -- G wires: box chest + 2 stores joined by script wires; read from box connector
    local boxG = surface.create_entity({ name = "steel-chest", position = { 30.5, 3.5 }, force = force })
    local sG = { surface.create_entity({ name = "sp-test-r2-chest", position = { 30.5, 3.5 }, force = force }), surface.create_entity({ name = "sp-test-r2-chest", position = { 30.5, 3.5 }, force = force }) }
    boxG.insert({ name = "coal", count = 3 }); sG[1].insert({ name = "iron-plate", count = 7 }); sG[2].insert({ name = "copper-plate", count = 5 }); sG[2].insert({ name = "iron-plate", count = 2 })
    try("wire", function()
      for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
        local bc = boxG.get_wire_connector(id, true)
        for _, s in ipairs(sG) do s.get_wire_connector(id, true).connect_to(bc, false, defines.wire_origin.script) end
      end
    end)
    local fedA, fedB, t = { 0, 0 }, { 0, 0 }, 0
    local seq = 0
    local function feed(belt, lane, name, tally)
      local line = belt.get_transport_line(lane)
      local k = 0
      while k < 4 and line.can_insert_at_back() do k = k + 1; if tally then tally[lane] = tally[lane] + 1 end; line.insert_at_back({ name = name, count = 1 }) end
    end
    local snapB
    on_tick(function()
      t = t + 1
      seq = seq + 1
      -- A: left lane alternates iron / copper by tick, right lane coal
      local lineA = feedA.get_transport_line(1)
      if lineA.can_insert_at_back() then fedA[1] = fedA[1] + 1; lineA.insert_at_back({ name = fedA[1] % 2 == 0 and "iron-plate" or "copper-plate", count = 1 }) end
      feed(feedA, 2, "coal", fedA)
      feed(feedB, 1, "iron-plate", fedB); feed(feedB, 2, "copper-plate", fedB)
      for _, f in ipairs({ feedC1, feedC2, feedD, feedF }) do feed(f, 1, "iron-plate"); feed(f, 2, "copper-plate") end
      if t == 600 then
        for lane = 1, 2 do for _, a in ipairs(armsB[lane]) do try("pause", function() a.disabled_by_script = true end) end end
      end
      if t == 630 then snapB = { count(storesB[1], "iron-plate"), count(storesB[2], "copper-plate"), fedB[1], fedB[2] } end
      if t >= 1200 then
        out[#out + 1] = string.format("A skip: storeL iron=%d copper=%d | storeR coal=%d | left belt items fed=%d (stall expected) | read filter=%s mode=%s", count(storesA[1], "iron-plate"), count(storesA[1], "copper-plate"), count(storesA[2], "coal"), fedA[1],
          tostring(armsA[1][1].get_filter(1) and armsA[1][1].get_filter(1).name), tostring(armsA[1][1].inserter_filter_mode))
        out[#out + 1] = string.format("B pause: at630 L=%d R=%d fed=%d/%d | at1200 L=%d R=%d fed=%d/%d | flag=%s", snapB[1], snapB[2], snapB[3], snapB[4], count(storesB[1], "iron-plate"), count(storesB[2], "copper-plate"), fedB[1], fedB[2], tostring(armsB[1][1].disabled_by_script))
        local function lanes(tag, s) out[#out + 1] = string.format("%s: storeL iron=%d copper=%d | storeR iron=%d copper=%d", tag, count(s[1], "iron-plate"), count(s[1], "copper-plate"), count(s[2], "iron-plate"), count(s[2], "copper-plate")) end
        lanes("C splitter", storesC); lanes("D underground", storesD); lanes("E loader(iron both lanes)", storesE); lanes("F north", storesF)
        local R, G = defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green
        local function sig(n, id) local ok, v = pcall(function() return boxG.get_signal({ type = "item", name = n }, id) end); return ok and tostring(v) or "ERR" end
        out[#out + 1] = string.format("G wires red: iron=%s copper=%s coal=%s | green: iron=%s", sig("iron-plate", R), sig("copper-plate", R), sig("coal", R), sig("iron-plate", G))
        local text = table.concat(out, " ;; ") .. " ;; notes[" .. table.concat(notes, " | ") .. "]"
        log("v15 probe misc: " .. text)
        error(text)
      end
    end)
  end)
end)
