-- Data stage: one tier = item, recipe, tech, placer, 4 container variants, remnant.
-- S0 builds yellow only; lane B extends BUILT_TIERS to all of N.TIERS and owns this file after S0.
local N = require("scripts.names")

local G = "__sushi-packer__/graphics/"
local BUILT_TIERS = { "yellow" }

local function layers(base)
  return {
    layers = {
      { filename = base .. ".png",        width = 128, height = 128, scale = 0.5 },
      { filename = base .. "-shadow.png", width = 128, height = 128, scale = 0.5, draw_as_shadow = true },
    },
  }
end

local function picture(tier, dir)
  return layers(G .. "entity/sushi-packer/" .. tier .. "/sushi-packer-" .. tier .. "-" .. dir)
end

local function icon(tier) return G .. "icons/sushi-packer-" .. tier .. ".png" end

local function make_tier(tier)
  local T = N.TIER[tier]
  local protos = {}

  protos[#protos + 1] = {
    type = "item",
    name = N.item(tier),
    icon = icon(tier), icon_size = 64,
    subgroup = "belt",
    order = "z[sushi-packer]-" .. tier,
    place_result = N.placer(tier),
    stack_size = 50,
  }

  protos[#protos + 1] = {
    type = "recipe",
    name = N.item(tier),
    enabled = false,
    energy_required = 1,
    ingredients = {
      { type = "item", name = "steel-chest", amount = 1 },
      { type = "item", name = T.belt, amount = 4 },
      { type = "item", name = T.circuit, amount = 5 },
    },
    results = { { type = "item", name = N.item(tier), amount = 1 } },
  }

  protos[#protos + 1] = {
    type = "technology",
    name = N.tech(tier),
    icon = icon(tier), icon_size = 64,
    prerequisites = { T.tech, "steel-processing" },
    effects = { { type = "unlock-recipe", recipe = N.item(tier) } },
    unit = { count = 50, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 15 },
  }

  local common = {
    icon = icon(tier), icon_size = 64,
    max_health = 350,
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    minable = { mining_time = 0.2, result = N.item(tier) },
    corpse = N.remnant(tier),
  }

  local placer = {
    type = "simple-entity-with-owner",
    name = N.placer(tier),
    flags = { "placeable-neutral", "player-creation" },
    picture = {
      north = picture(tier, "north"), east = picture(tier, "east"),
      south = picture(tier, "south"), west = picture(tier, "west"),
    },
    hidden_in_factoriopedia = true,
  }
  for k, v in pairs(common) do placer[k] = v end
  protos[#protos + 1] = placer

  for _, dir in ipairs(N.DIRS) do
    local box = {
      type = "container",
      name = N.variant(tier, dir),
      flags = { "placeable-neutral", "player-creation", "not-rotatable" },
      placeable_by = { item = N.item(tier), count = 1 },
      fast_replaceable_group = N.FAST_REPLACE_GROUP,
      inventory_size = N.SLOTS,
      picture = picture(tier, dir),
      circuit_connector = circuit_connector_definitions["chest"],
      circuit_wire_max_distance = default_circuit_wire_max_distance,
      hidden_in_factoriopedia = dir ~= "north",
    }
    for k, v in pairs(common) do box[k] = v end
    protos[#protos + 1] = box
  end

  protos[#protos + 1] = {
    type = "corpse",
    name = N.remnant(tier),
    icon = icon(tier), icon_size = 64,
    flags = { "placeable-neutral", "not-on-map" },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    tile_width = 1, tile_height = 1,
    time_before_removed = 60 * 60 * 15,
    final_render_layer = "remnants",
    animation = layers(G .. "entity/sushi-packer/" .. tier .. "/remnants/sushi-packer-" .. tier .. "-remnants"),
  }

  return protos
end

for _, tier in ipairs(BUILT_TIERS) do
  data:extend(make_tier(tier))
end
