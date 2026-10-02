local F = require("tests.offline.fake_data")
local N = require("scripts.names")

local function load()
  F.reset()
  dofile("prototypes/packer.lua")
  return F.raw
end

local function ingredients(recipe)
  local out = {}
  for _, ingredient in ipairs(recipe.ingredients) do
    out[#out + 1] = { ingredient.name, ingredient.amount }
  end
  return out
end

local function science_names(unit)
  local out = {}
  for _, ingredient in ipairs(unit.ingredients) do out[#out + 1] = ingredient[1] end
  return out
end

describe("data v17", function()
  local function deep_equal(a, b, path)
    eq(a, b, path)
  end

  it("body is belt copy per tier", function()
    local raw = load()
    local source = table.deepcopy(raw["transport-belt"][N.TIER.yellow.belt])
    local body = raw["transport-belt"][N.body("yellow")]
    ok(body ~= nil, "yellow body missing")
    for _, key in ipairs({ "speed", "belt_animation_set", "collision_box", "circuit_connector" }) do
      deep_equal(body[key], source[key], key)
    end
    eq(raw["transport-belt"][N.TIER.yellow.belt], source, "source belt changed")
  end)

  it("body fields", function()
    local raw = load()
    local body = raw["transport-belt"][N.body("yellow")]
    eq(body.type, "transport-belt"); eq(body.name, N.body("yellow"))
    eq(body.icon, "__sushi-packer__/graphics/icons/sushi-packer-yellow.png"); eq(body.icon_size, 64)
    eq(body.localised_name, { "entity-name." .. N.placer("yellow") })
    eq(body.minable, { mining_time = 0.2, result = N.item("yellow") })
    eq(body.placeable_by, { item = N.item("yellow"), count = 1 })
    eq(body.fast_replaceable_group, N.FAST_REPLACE_GROUP)
    eq(body.related_underground_belt, nil); eq(body.corpse, N.remnant("yellow"))
    eq(body.max_health, 350); eq(body.se_allow_in_space, true); eq(body.icons, nil)
    eq(body.factoriopedia_simulation, raw.item[N.item("yellow")].factoriopedia_simulation)
    eq(body.hidden_in_factoriopedia, false)
  end)

  it("body upgrade chain", function()
    local raw = load()
    eq(raw["transport-belt"][N.body("yellow")].next_upgrade, N.body("red"))
    eq(raw["transport-belt"][N.body("red")].next_upgrade, N.body("blue"))
    eq(raw["transport-belt"][N.body("blue")].next_upgrade, N.body("turbo"))
    eq(raw["transport-belt"][N.body("turbo")].next_upgrade, nil)
  end)

  it("hood fields", function()
    local raw = load()
    local hood = raw["simple-entity-with-owner"][N.hood("yellow")]
    local placer = raw["simple-entity-with-owner"][N.placer("yellow")]
    ok(hood ~= nil, "yellow hood missing")
    eq(hood.type, "simple-entity-with-owner"); eq(hood.picture, placer.picture)
    eq(hood.collision_mask, { layers = {} }); eq(hood.selectable_in_game, false)
    eq(hood.hidden, true); eq(hood.hidden_in_factoriopedia, true)
    eq(hood.flags, { "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable", "not-flammable", "not-in-kill-statistics", "not-repairable", "placeable-neutral" })
    eq(hood.minable, nil); eq(hood.max_health, 350); eq(hood.render_layer, "object")
  end)

  it("legacy boxes hidden without upgrade", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do for _, dir in ipairs(N.DIRS) do
      local box = raw.container[N.variant(tier, dir)]
      eq(box.type, "container"); eq(box.inventory_size, N.SLOTS); eq(box.hidden, true)
      eq(box.hidden_in_factoriopedia, true); eq(box.next_upgrade, nil)
      eq(box.factoriopedia_simulation, nil); eq(box.placeable_by, { item = N.item(tier), count = 1 })
    end end
  end)

  it("item still places placer", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do eq(raw.item[N.item(tier)].place_result, N.placer(tier)) end
  end)
end)

describe("data", function()
  it("own subgroup row after belts", function()
    local raw = load()
    local row = raw["item-subgroup"][N.SUBGROUP]
    eq(row.group, "logistics"); eq(row.order, "b-a")
    local count = 0
    for _, prototype in ipairs(F.extended) do if prototype.type == "item-subgroup" and prototype.name == N.SUBGROUP then count = count + 1 end end
    eq(count, 1, "subgroup is extended once")
    for _, tier in ipairs(N.TIERS) do eq(raw.item[N.item(tier)].subgroup, N.SUBGROUP) end
  end)

  it("order yellow red blue turbo", function()
    local raw = load()
    for i, tier in ipairs(N.TIERS) do eq(raw.item[N.item(tier)].order, "a[sushi-packer]-" .. string.char(96 + i), tier) end
  end)

  it("item names follow vanilla series", function()
    eq({ N.item("yellow"), N.item("red"), N.item("blue"), N.item("turbo") },
      { "sushi-packer", "fast-sushi-packer", "express-sushi-packer", "turbo-sushi-packer" })
  end)

  it("simulations call scene with mods", function()
    local raw = load()
    dofile("prototypes/tips.lua")
    local expected = { mods = { "sushi-packer" }, init_update_count = 900, checkboard = true }
    for _, tier in ipairs(N.TIERS) do
      expected.init = 'remote.call("sushi-packer", "scene", "factoriopedia")'
      eq(raw.item[N.item(tier)].factoriopedia_simulation, expected, tier .. " item")
      expected.init = 'remote.call("sushi-packer", "scene", "factoriopedia")'
      eq(raw.container[N.variant(tier, "north")].factoriopedia_simulation, expected, tier .. " north")
    end
    expected.init = 'remote.call("sushi-packer", "scene", "tips")'
    eq(raw["tips-and-tricks-item"][N.TIPS].simulation, expected)
  end)

  it("simulations pre-run 900 ticks", function()
    local raw = load()
    dofile("prototypes/tips.lua")
    for _, tier in ipairs(N.TIERS) do
      eq(raw.item[N.item(tier)].factoriopedia_simulation.init_update_count, 900, tier .. " item")
      eq(raw.container[N.variant(tier, "north")].factoriopedia_simulation.init_update_count, 900, tier .. " north")
    end
    eq(raw["tips-and-tricks-item"][N.TIPS].simulation.init_update_count, 900)
  end)

  it("placer joins belt group variants do not", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do
      eq(raw["simple-entity-with-owner"][N.placer(tier)].fast_replaceable_group, N.BELT_GROUP)
      for _, dir in ipairs(N.DIRS) do eq(raw.container[N.variant(tier, dir)].fast_replaceable_group, N.FAST_REPLACE_GROUP) end
    end
  end)

  it("yellow recipe matches table", function()
    local raw = load()
    eq(ingredients(raw.recipe[N.item("yellow")]), {
      { "steel-chest", 1 }, { "splitter", 1 }, { "inserter", 2 }, { "electronic-circuit", 5 },
    })
    eq(raw.recipe[N.item("yellow")].energy_required, 30)
  end)

  it("chained tiers use previous box", function()
    local raw = load()
    for _, tier in ipairs({ "red", "blue", "turbo" }) do
      local previous = { red = "yellow", blue = "red", turbo = "blue" }
      eq(ingredients(raw.recipe[N.item(tier)])[1], { N.item(previous[tier]), 1 }, tier .. " base")
    end
    eq(ingredients(raw.recipe[N.item("turbo")]), {
      { N.item("blue"), 1 }, { "turbo-splitter", 1 }, { "stack-inserter", 2 }, { "quantum-processor", 2 },
    })
  end)

  it("craft times 30 45 60 120", function()
    local raw = load()
    for i, tier in ipairs(N.TIERS) do eq(raw.recipe[N.item(tier)].energy_required, ({ 30, 45, 60, 120 })[i]) end
  end)

  it("recipes disabled until research", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do eq(raw.recipe[N.item(tier)].enabled, false, tier) end
  end)

  it("tech prereqs include ingredient unlock techs", function()
    local raw = load()
    local expected = {
      { "logistics", "steel-processing", "electronics" },
      { "logistics-2", "sushi-packer", "fast-inserter", "advanced-circuit" },
      { "logistics-3", "fast-sushi-packer", "bulk-inserter", "processing-unit" },
      { "turbo-transport-belt", "express-sushi-packer", "stack-inserter", "quantum-processor" },
    }
    for i, tier in ipairs(N.TIERS) do eq(raw.technology[N.tech(tier)].prerequisites, expected[i], tier) end
  end)

  it("tech count is belt count x 1.5", function()
    local raw = load()
    for i, tier in ipairs(N.TIERS) do
      local unit = raw.technology[N.tech(tier)].unit
      eq(unit.count, ({ 30, 300, 450, 750 })[i], tier .. " count")
      eq(unit.time, ({ 15, 30, 15, 60 })[i], tier .. " time")
    end
  end)

  it("tech ingredients are union over prereqs", function()
    local raw = load()
    local expected = {
      { "automation-science-pack" },
      { "automation-science-pack", "logistic-science-pack" },
      { "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack" },
      { "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack", "space-science-pack", "metallurgic-science-pack", "utility-science-pack", "agricultural-science-pack", "electromagnetic-science-pack", "cryogenic-science-pack" },
    }
    for i, tier in ipairs(N.TIERS) do eq(science_names(raw.technology[N.tech(tier)].unit), expected[i], tier) end
  end)

  it("tech unlocks its recipe", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do
      eq(raw.technology[N.tech(tier)].effects, { { type = "unlock-recipe", recipe = N.item(tier) } }, tier)
    end
  end)

  it("next_upgrade chain keeps direction", function()
    local raw = load()
    eq(raw.container[N.variant("yellow", "east")].next_upgrade, N.variant("red", "east"))
    eq(raw.container[N.variant("blue", "west")].next_upgrade, N.variant("turbo", "west"))
    eq(raw.container[N.variant("turbo", "west")].next_upgrade, nil)
  end)

  it("item weight 20 kg", function()
    local raw = load()
    for _, tier in ipairs(N.TIERS) do eq(raw.item[N.item(tier)].weight, 20000, tier) end
  end)

  it("no surface conditions", function()
    local raw = load()
    for _, prototypes in pairs(raw) do
      for name, prototype in pairs(prototypes) do
        eq(prototype.surface_conditions, nil, name)
      end
    end
  end)
end)
