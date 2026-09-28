-- v9 modded belt tiers (REQUIREMENTS §17) on the real engine. Integrator-owned (SP-02): runs in vanilla full suite
-- (expects no extras) and once per mod set via `make test-modsets FV=` (MODSET, tools/modsets.json).
-- Expected tiers come from installed mods (script.active_mods + Arig startup setting), never from N.EXTRA logic.
local N = require("scripts.names")
local registry = require("scripts.registry")

local NORTH = defines.direction.north

-- FND-0023 real rows, in chain order (belt speed ascending, tie = N.EXTRA row order).
local function expected_extras()
  local m = script.active_mods
  local hyper_off = settings.startup["disable-hyper-belts"] and settings.startup["disable-hyper-belts"].value
  local ub, out = m["UltimateBeltsSpaceAge"], {}
  local rows = {
    { "planetaris-hyper", m["planetaris-arig"] and not hyper_off },
    { "bob-ultimate", m["boblogistics"] },
    { "kr-superior", m["Krastorio2-spaced-out"] },
    { "ub-ultra-fast", ub },
    { "bb-ultra", m["BetterBelts"] },
    { "ub-extreme-fast", ub },
    { "ub-ultra-express", ub },
    { "ub-extreme-express", ub },
    { "ub-ultimate", ub },
  }
  for _, r in ipairs(rows) do if r[2] then out[#out + 1] = r[1] end end
  return out
end

local function chain()
  local c = { "turbo" }
  for _, k in ipairs(expected_extras()) do c[#c + 1] = k end
  return c
end

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
    local want = { "yellow", "red", "blue", "turbo" }
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
    local c = chain()
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
  end)

  it("tech unlocks recipe and every ingredient reachable", function()
    local c = chain()
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
      assert.are_equal(N.item(prev), recipe.ingredients[1].name, "chained " .. key)
      assert.are_equal(120, recipe.energy)
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
  end)

  it("box output matches belt rate", function()
    -- Per tier (turbo = control): 3 own belts behind, box, 12 own belts in front, north. Belt stack 1 = every item
    -- leaves at once (C-2). Both lanes saturated from far behind; last front tile emptied each tick and counted.
    -- Warm-up 180 ticks, measure 600. Want belt items per lane = belt_speed * 4 * 600 (M-6), within 3 % + 2.
    force.belt_stack_size_bonus = 0
    local rigs = {}
    for i, key in ipairs(chain()) do
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

  it("upgrade turbo to next tier keeps state", function()
    local c = chain()
    if #c < 2 then return end  -- vanilla: no extra tier (upgrade covered by lifecycle > upgrade keeps state)
    local nxt = c[2]
    local sink = surface.create_entity({ name = "electric-energy-interface", position = { 20, 20 }, force = force })
    sink.power_production = 1e9; sink.electric_buffer_size = 1e9; sink.energy = 1e9
    surface.create_entity({ name = "medium-electric-pole", position = { 18, 20 }, force = force })
    local port = surface.create_entity({ name = "roboport", position = { 16, 22 }, force = force })
    port.insert({ name = "construction-robot", count = 4 })
    surface.create_entity({ name = "storage-chest", position = { 13, 20 }, force = force }).insert({ name = N.item(nxt), count = 1 })
    local old = surface.create_entity({ name = N.variant("turbo", "east"), position = { 10.5, 18.5 }, force = force, raise_built = true })
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
end)
