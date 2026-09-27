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
