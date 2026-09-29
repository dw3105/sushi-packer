-- v9 modded belt tiers (REQUIREMENTS §17) on the real engine. Integrator-owned (SP-02): runs in vanilla full suite
-- (expects no extras) and once per mod set via `make test-modsets FV=` (MODSET, tools/modsets.json).
-- Expected tiers come from installed mods (script.active_mods + Arig startup setting), never from N.EXTRA logic.
local N = require("scripts.names")
local registry = require("scripts.registry")

local NORTH = defines.direction.north

-- v10: top vanilla tier = turbo with space-age, blue without (Q6). Expected from installed mods, never from N.EXTRA logic.
local function top_vanilla() return script.active_mods["space-age"] and "turbo" or "blue" end
local function vanilla()
  return script.active_mods["space-age"] and { "yellow", "red", "blue", "turbo" } or { "yellow", "red", "blue" }
end

-- FND-0023 + FND-0028 real rows, in N.EXTRA row order (= tie order). Kept: owner mod loaded and belt faster than
-- top vanilla belt (Q7, Q11). Chain order = live belt speed ascending, tie by this list order (M-4).
local function expected_extras()
  local m = script.active_mods
  local hyper_off = settings.startup["disable-hyper-belts"] and settings.startup["disable-hyper-belts"].value
  local ub, ab = m["UltimateBeltsSpaceAge"], m["AdvancedBeltsUpdated"]
  local rows = {
    { "planetaris-hyper", m["planetaris-arig"] and not hyper_off, "planetaris-hyper-transport-belt" },
    { "bob-ultimate", m["boblogistics"], "bob-ultimate-transport-belt" },
    { "kr-superior", m["Krastorio2-spaced-out"] or m["Krastorio2"], "kr-superior-transport-belt" },
    { "ub-ultra-fast", ub, "ultra-fast-belt" },
    { "bb-ultra", m["BetterBelts"], "BetterBelts_ultra-transport-belt" },
    { "ub-extreme-fast", ub, "extreme-fast-belt" },
    { "ub-ultra-express", ub, "ultra-express-belt" },
    { "ub-extreme-express", ub, "extreme-express-belt" },
    { "ub-ultimate", ub, "ultimate-belt" },
    { "ab-elite", ab, "elite-belt" },
    { "ab-extreme", ab, "extreme-belt" },
    { "ab-supreme", ab, "supreme-belt" },
    { "ab-ultimate", ab, "ultimate-belt" },
    -- v11 (V11-1, V11-2): SE space = own-role root (kept at 45/s), deep space after it (separate chain)
    { "se-space", m["space-exploration"], "se-space-transport-belt", { root = true } },
    { "se-deep-space", m["space-exploration"], "se-deep-space-transport-belt-black", { after = "se-space" } },
  }
  local top = prototypes.entity[top_vanilla() == "turbo" and "turbo-transport-belt" or "express-transport-belt"].belt_speed
  local out, kept = {}, {}
  for i, r in ipairs(rows) do
    local o = r[4] or {}
    if r[2] and (o.after == nil or kept[o.after]) then
      local speed = prototypes.entity[r[3]].belt_speed
      if speed > top or o.root then out[#out + 1] = { key = r[1], speed = speed, i = i, o = o }; kept[r[1]] = true end
    end
  end
  table.sort(out, function(x, y) if x.speed == y.speed then return x.i < y.i end return x.speed < y.speed end)
  local keys, opts = {}, {}
  for i, r in ipairs(out) do keys[i] = r.key; opts[r.key] = r.o end
  return keys, opts
end

-- v11 (M-4, U-3): chains. Main = top vanilla + plain extras by speed; root row starts own chain; `after` row
-- joins chain of its target. First chain = main.
local function chains()
  local keys, opts = expected_extras()
  local list, where = { { top_vanilla() } }, {}
  for _, k in ipairs(keys) do
    local o, c = opts[k], nil
    if o.after then c = where[o.after] elseif o.root then c = {}; list[#list + 1] = c else c = list[1] end
    c[#c + 1] = k; where[k] = c
  end
  return list
end

local function chain() return chains()[1] end

local function clear(surface)
  for _, e in ipairs(surface.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
end

describe("modtiers", function()
  local surface, force
  before_each(function()
    surface, force = game.surfaces[1], game.forces.player
    clear(surface)
    storage.boxes = {}
    storage.belt_stack = {}
  end)

  it("active tiers match installed mods", function()
    local want = vanilla()
    for _, k in ipairs(expected_extras()) do want[#want + 1] = k end
    local got = N.active()
    table.sort(got, function(a, b)
      local ia, ib
      for i, k in ipairs(want) do if k == a then ia = i end; if k == b then ib = i end end
      return (ia or 99) < (ib or 99)
    end)
    assert.are.same(want, got)
    for _, row in ipairs(N.EXTRA) do
      local on = false
      for _, k in ipairs(want) do if k == row.key then on = true end end
      assert.are_equal(on, prototypes.item[N.item(row.key)] ~= nil, "item presence " .. row.key)
    end
  end)

  it("upgrade chain follows belt speed", function()
    for _, c in ipairs(chains()) do
    for i, key in ipairs(c) do
      local nxt = c[i + 1]
      for _, dir in ipairs(N.DIRS) do
        local p = prototypes.entity[N.variant(key, dir)]
        if nxt then assert.are_equal(N.variant(nxt, dir), p.next_upgrade and p.next_upgrade.name, key .. " " .. dir)
        else assert.is_nil(p.next_upgrade, key .. " last") end
      end
      if nxt then
        assert.is_true(prototypes.entity[N.TIER[nxt].belt].belt_speed >= prototypes.entity[N.TIER[key].belt].belt_speed, nxt .. " not slower")
        assert.is_true(prototypes.item[N.item(nxt)].order > prototypes.item[N.item(key)].order, nxt .. " sorts after " .. key)
      end
    end
    end
  end)

  it("root tier recipe and tech have no previous box", function()
    -- v11 (M-5, U-1, V11-3): root = first of a non-main chain. Recipe: steel-chest 1 + own splitter 1 + inserters and
    -- circuits x2, no box item; tech: no sushi-packer tech prereq.
    local list = chains()
    for ci = 2, #list do
      local key = list[ci][1]
      local recipe = prototypes.recipe[N.item(key)]
      local got = {}
      for _, ing in ipairs(recipe.ingredients) do got[ing.name] = ing.amount end
      assert.are_equal(1, got["steel-chest"], key .. " steel-chest")
      assert.are_equal(1, got[N.TIER[key].splitter], key .. " splitter")
      for name in pairs(got) do assert.is_nil(name:find("sushi-packer", 1, true), key .. " no box in recipe: " .. name) end
      if key == "se-space" then
        assert.are_equal(4, got["bulk-inserter"]); assert.are_equal(10, got["processing-unit"]); assert.are_equal(60, recipe.energy)
      end
      local tech = prototypes.technology[N.tech(key)]
      assert.is_not_nil(tech.prerequisites[N.TIER[key].tech], "belt tech prereq " .. key)
      for p in pairs(tech.prerequisites) do assert.is_nil(p:find("sushi-packer", 1, true), key .. " no tier tech prereq: " .. p) end
      assert.are_equal(prototypes.technology[N.TIER[key].tech].research_unit_count * 1.5, tech.research_unit_count, key .. " count")
    end
  end)

  it("tech unlocks recipe and every ingredient reachable", function()
    for _, c in ipairs(chains()) do
    for i = 2, #c do
      local key, prev = c[i], c[i - 1]
      local tech = prototypes.technology[N.tech(key)]
      assert.is_not_nil(tech, "tech " .. key)
      local unlocks = false
      for _, e in ipairs(tech.effects) do if e.type == "unlock-recipe" and e.recipe == N.item(key) then unlocks = true end end
      assert.is_true(unlocks, "tech unlocks recipe " .. key)
      assert.is_not_nil(tech.prerequisites[N.TIER[key].tech], "belt tech prereq " .. key)
      assert.is_not_nil(tech.prerequisites[N.tech(prev)], "previous tier tech prereq " .. key)
      local closure, todo = {}, { tech.name }
      while #todo > 0 do
        local t = table.remove(todo)
        if not closure[t] then
          closure[t] = true
          for p in pairs(prototypes.technology[t].prerequisites) do todo[#todo + 1] = p end
        end
      end
      local recipe = prototypes.recipe[N.item(key)]
      local has_prev = false  -- runtime ingredient order not kept (measured 2.0.77: quantum-processor first)
      for _, ing in ipairs(recipe.ingredients) do if ing.name == N.item(prev) and ing.amount == 1 then has_prev = true end end
      assert.is_true(has_prev, "chained " .. key .. " needs 1 " .. N.item(prev))
      assert.are_equal(script.active_mods["space-age"] and 120 or 60, recipe.energy)  -- v10 Q6: no-SA recipe = blue set
      for _, ing in ipairs(recipe.ingredients) do
        local reach = false
        for t in pairs(closure) do
          for _, e in ipairs(prototypes.technology[t].effects) do
            if e.type == "unlock-recipe" and e.recipe == ing.name then reach = true end
          end
        end
        assert.is_true(reach, key .. " ingredient " .. ing.name .. " unlocked in prereq closure")
      end
    end
    end
  end)

  it("box output matches belt rate", function()
    -- Per tier (turbo = control): 3 own belts behind, box, 12 own belts in front, north. Belt stack 1 = every item
    -- leaves at once (C-2). Both lanes saturated from far behind; last front tile emptied each tick and counted.
    -- Warm-up 180 ticks, measure 600. Want belt items per lane = belt_speed * 4 * 600 (M-6), within 3 % + 2.
    force.belt_stack_size_bonus = 0
    local rigs = {}
    -- FND-0030: blue always measured (was only a chain tier without space-age; 200/225 per lane before fix).
    local tiers = {}
    for _, c in ipairs(chains()) do for _, k in ipairs(c) do tiers[#tiers + 1] = k end end  -- v11: every chain
    if tiers[1] ~= "blue" then table.insert(tiers, 1, "blue") end
    for i, key in ipairs(tiers) do
      local x, belt = (i - 1) * 4, N.TIER[key].belt
      local behind = {}
      for j = 1, 3 do behind[j] = surface.create_entity({ name = belt, position = { x + 0.5, 0.5 + j }, direction = NORTH, force = force }) end
      local front = {}
      for j = 1, 12 do front[j] = surface.create_entity({ name = belt, position = { x + 0.5, 0.5 - j }, direction = NORTH, force = force }) end
      surface.create_entity({ name = N.placer(key), position = { x + 0.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
      rigs[#rigs + 1] = { key = key, feed = behind[3], last = front[12], got = { 0, 0 },
        want = prototypes.entity[belt].belt_speed * 4 * 600 }
    end
    local names = { "iron-plate", "copper-plate", "coal", "stone" }
    local t, n = 0, 0
    on_tick(function()
      t = t + 1
      for _, r in ipairs(rigs) do
        for lane = 1, 2 do
          local line = r.feed.get_transport_line(lane)
          local k = 0
          while k < 4 and line.can_insert_at_back() do
            n = n + 1; k = k + 1
            line.insert_at_back({ name = names[n % #names + 1], count = 1 })
          end
          local out = r.last.get_transport_line(lane)
          if t > 180 then for _, s in ipairs(out.get_contents()) do r.got[lane] = r.got[lane] + s.count end end
          out.clear()
        end
      end
      if t >= 780 then
        local report = {}
        for _, r in ipairs(rigs) do
          for lane = 1, 2 do
            local ok = math.abs(r.got[lane] - r.want) <= r.want * 0.03 + 2
            report[#report + 1] = string.format("%s lane%d got=%d want=%.1f %s", r.key, lane, r.got[lane], r.want, ok and "ok" or "BAD")
          end
        end
        local text = table.concat(report, "; ")
        log("modtiers rate: " .. text)  -- green run keeps numbers (build/<FV>/ftdata*/factorio-current.log)
        assert.is_nil(text:find("BAD", 1, true), text)
        return false
      end
    end)
  end)

  it("upgrade top vanilla to next tier keeps state", function()
    local c = chain()
    if #c < 2 then return end  -- vanilla: no extra tier (upgrade covered by lifecycle > upgrade keeps state)
    local nxt = c[2]
    local sink = surface.create_entity({ name = "electric-energy-interface", position = { 20, 20 }, force = force })
    sink.power_production = 1e9; sink.electric_buffer_size = 1e9; sink.energy = 1e9
    surface.create_entity({ name = "medium-electric-pole", position = { 18, 20 }, force = force })
    local port = surface.create_entity({ name = "roboport", position = { 16, 22 }, force = force })
    port.insert({ name = "construction-robot", count = 4 })
    surface.create_entity({ name = "storage-chest", position = { 13, 20 }, force = force }).insert({ name = N.item(nxt), count = 1 })
    local old = surface.create_entity({ name = N.variant(c[1], "east"), position = { 10.5, 18.5 }, force = force, raise_built = true })
    local rec = registry.get(old)
    rec.settings.timeout_s = 33
    old.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 7 })
    assert.is_true(old.order_upgrade({ target = N.variant(nxt, "east"), force = force }))
    after_ticks(1200, function()
      local new = surface.find_entities_filtered({ position = { 10.5, 18.5 }, radius = 0.4, name = N.variant(nxt, "east") })[1]
      assert.is_not_nil(new, "upgraded to " .. nxt)
      local nr = registry.get(new)
      assert.is_not_nil(nr, "rec carried")
      assert.are_equal(nxt, nr.tier); assert.are_equal("east", nr.dir)
      assert.are_equal(33, nr.settings.timeout_s)
      assert.are_equal(7, new.get_inventory(defines.inventory.chest).get_item_count("iron-plate"))
    end)
  end)

  it("box releases stacks at research bonus", function()
    -- v10 T-1 (FND-0025): with or without space-age, box on own top vanilla belt, bonus 3 -> belt stack 4 (O-3).
    -- 8 iron plates on lane 1 behind; after 600 ticks the front belts hold stacked belt items of 4.
    force.belt_stack_size_bonus = 3
    local key = top_vanilla()
    local belt = N.TIER[key].belt
    local behind = surface.create_entity({ name = belt, position = { 30.5, 1.5 }, direction = NORTH, force = force })
    for j = 1, 6 do surface.create_entity({ name = belt, position = { 30.5, 0.5 - j }, direction = NORTH, force = force }) end
    surface.create_entity({ name = N.placer(key), position = { 30.5, 0.5 }, direction = NORTH, force = force, raise_built = true })
    local fed, t = 0, 0  -- insert_at_back fills only a free back spot: feed over ticks, not 8 in one tick
    on_tick(function()
      t = t + 1
      local line = behind.get_transport_line(1)
      if fed < 8 and line.can_insert_at_back() then line.insert_at_back({ name = "iron-plate", count = 1 }); fed = fed + 1 end
      if t >= 600 then return false end
    end)
    after_ticks(600, function()
      assert.are_equal(8, fed, "fed 8 plates")
      local stacks = {}
      for _, e in ipairs(surface.find_entities_filtered({ area = { { 30, -6 }, { 31, 0 } }, name = belt })) do
        for lane = 1, 2 do
          for _, d in ipairs(e.get_transport_line(lane).get_detailed_contents()) do stacks[#stacks + 1] = d.stack.count end
        end
      end
      table.sort(stacks)
      assert.are.same({ 4, 4 }, stacks, "stacked output " .. key)
    end)
  end)

  it("box placeable in se space", function()
    -- v10 Q10: SE blocks containers on space tiles (scaffold = what players build on) unless se_allow_in_space.
    -- Control: plain belt blocked there, space belt allowed.
    if not script.active_mods["space-exploration"] then return end
    local s = game.create_surface("sp-space-test")
    s.request_to_generate_chunks({ 0, 0 }, 1); s.force_generate_chunk_requests()
    local tiles = {}
    for x = -3, 3 do for y = -3, 3 do tiles[#tiles + 1] = { name = "se-space-platform-scaffold", position = { x, y } } end end
    s.set_tiles(tiles)
    for _, e in ipairs(s.find_entities_filtered({ area = { { -3, -3 }, { 3, 3 } } })) do if e.type ~= "character" then e.destroy() end end
    assert.is_false(s.can_place_entity({ name = "transport-belt", position = { 0.5, 0.5 }, force = force }), "control: plain belt blocked in space")
    assert.is_true(s.can_place_entity({ name = "se-space-transport-belt", position = { 0.5, 1.5 }, force = force }), "space belt allowed")
    for _, key in ipairs(N.active()) do
      assert.is_true(s.can_place_entity({ name = N.variant(key, "north"), position = { 0.5, 0.5 }, force = force }), "box in space " .. key)
    end
    game.delete_surface(s)
  end)
end)
