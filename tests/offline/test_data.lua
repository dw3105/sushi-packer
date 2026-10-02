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

local function hood_path(tier, dir)
  return "__sushi-packer__/graphics/entity/sushi-packer/" .. tier .. "/sushi-packer-" .. tier .. "-" .. dir .. ".png"
end

describe("data v20", function()
  local tier_builder = require("prototypes.tier")
  local function picture_set()
    return { animation_set = { filename = "vanilla.png", frame_count = 16, direction_count = 20 } }
  end

  it("body has no connector frame", function()
    local raw = load()
    local source = raw["transport-belt"][N.TIER.yellow.belt]
    local body = raw["transport-belt"][N.body("yellow")]
    eq(body.connector_frame_sprites, nil)
    eq(body.circuit_connector, source.circuit_connector)
  end)

  it("hood layer rows follow leaving direction", function()
    local layer = tier_builder._hood_layer("yellow", picture_set())
    local dirs = { "east", "west", "north", "south", "north", "east", "north", "west", "east", "south", "west", "south", "south", "south", "west", "west", "north", "north", "east", "east" }
    for row, dir in ipairs(dirs) do eq(layer.filenames[row], hood_path("yellow", dir), "row " .. row) end
  end)

  it("hood layer follows custom index fields", function()
    local layer = tier_builder._hood_layer("yellow", { animation_set = { frame_count = 1, direction_count = 20 }, east_index = 3, north_index = 1 })
    eq(layer.filenames[3], hood_path("yellow", "east")); eq(layer.filenames[1], hood_path("yellow", "north"))
  end)

  it("hood layer repeat count equals belt frames", function()
    local set = { animation_set = { frame_count = 32, direction_count = 20 } }
    eq(tier_builder._hood_layer("yellow", set).repeat_count, 32)
    local old = { filename = "base.png", frame_count = 16 }
    set.animation_set = { layers = { old, { filename = "other.png" } }, direction_count = 20 }
    local layer = tier_builder._hood_layer("yellow", set)
    eq(layer.repeat_count, 16)
    local raw = load()
    local source = raw["transport-belt"][N.TIER.yellow.belt]
    source.belt_animation_set = { animation_set = { layers = { old, { filename = "other.png" } }, direction_count = 20 } }
    local body = tier_builder.make("yellow", { index = 1 })
    local body_proto
    for _, proto in ipairs(body) do if proto.name == N.body("yellow") then body_proto = proto end end
    local layers = body_proto.belt_animation_set.animation_set.layers
    eq(layers[1], old); eq(layers[2], { filename = "other.png" }); eq(layers[3], layer)
  end)

  it("odd belt picture keeps belt picture", function()
    local cases = {
      { animation_set = { direction_count = 12 } },
      {},
      { animation_set = { direction_count = 20 }, east_index = 21 },
      { animation_set = { direction_count = 20 }, east_index = 1, north_index = 1 },
    }
    for _, set in ipairs(cases) do eq(tier_builder._hood_layer("yellow", set), nil) end
    local raw = load()
    local source = raw["transport-belt"][N.TIER.yellow.belt]
    source.belt_animation_set = { animation_set = { direction_count = 12 } }
    local original = table.deepcopy(source.belt_animation_set)
    local protos = tier_builder.make("yellow", { index = 1 })
    for _, proto in ipairs(protos) do if proto.name == N.body("yellow") then eq(proto.belt_animation_set, original) end end
  end)

  it("source belt picture not modified", function()
    F.reset()
    local source = F.raw["transport-belt"][N.TIER.yellow.belt]
    local before = table.deepcopy(source.belt_animation_set)
    tier_builder.make("yellow", { index = 1 })
    eq(source.belt_animation_set, before)
    local body
    for _, proto in ipairs(tier_builder.make("yellow", { index = 1 })) do if proto.name == N.body("yellow") then body = proto end end
    ok(body.belt_animation_set ~= source.belt_animation_set)
    ok(body.belt_animation_set.animation_set.layers ~= nil, "body hood overlay missing")
    eq(source.belt_animation_set, before)
  end)

  it("body picture is belt plus hood", function()
    local raw = load()
    local source = raw["transport-belt"][N.TIER.yellow.belt].belt_animation_set.animation_set
    local source_set = raw["transport-belt"][N.TIER.yellow.belt].belt_animation_set
    local body = raw["transport-belt"][N.body("yellow")]
    local layers = body.belt_animation_set.animation_set.layers
    eq(layers[1], source)
    eq(layers[#layers], tier_builder._hood_layer("yellow", source_set))
  end)
end)

describe("data v17", function()
  local function deep_equal(a, b, path)
    eq(a, b, path)
  end

  it("body is belt copy per tier", function()
    local raw = load()
    local source = table.deepcopy(raw["transport-belt"][N.TIER.yellow.belt])
    local body = raw["transport-belt"][N.body("yellow")]
    ok(body ~= nil, "yellow body missing")
    for _, key in ipairs({ "speed", "collision_box", "circuit_connector" }) do
      deep_equal(body[key], source[key], key)
    end
    eq(body.belt_animation_set.animation_set.layers[1], source.belt_animation_set.animation_set)
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
    eq(hood.icon, placer.icon); eq(hood.icon_size, 64)  -- INT: engine refuses entity without icon (load error 2026-10-02)
    eq(hood.collision_mask, { layers = {} }); eq(hood.selectable_in_game, false)
    eq(hood.hidden, true); eq(hood.hidden_in_factoriopedia, true)
    eq(hood.flags, { "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable", "not-flammable", "not-in-kill-statistics", "not-repairable", "placeable-neutral", "placeable-off-grid" })
    eq(hood.collision_box, { { -0.35, -0.35 }, { 0.35, 0.35 } })
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
      eq(raw["transport-belt"][N.body(tier)].factoriopedia_simulation, expected, tier .. " body")
    end
    expected.init = 'remote.call("sushi-packer", "scene", "tips")'
    eq(raw["tips-and-tricks-item"][N.TIPS].simulation, expected)
  end)

  it("simulations pre-run 900 ticks", function()
    local raw = load()
    dofile("prototypes/tips.lua")
    for _, tier in ipairs(N.TIERS) do
      eq(raw.item[N.item(tier)].factoriopedia_simulation.init_update_count, 900, tier .. " item")
      eq(raw["transport-belt"][N.body(tier)].factoriopedia_simulation.init_update_count, 900, tier .. " body")
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

  it("body upgrade chain follows tier order", function()
    local raw = load()
    eq(raw["transport-belt"][N.body("yellow")].next_upgrade, N.body("red"))
    eq(raw["transport-belt"][N.body("blue")].next_upgrade, N.body("turbo"))
    eq(raw["transport-belt"][N.body("turbo")].next_upgrade, nil)
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
