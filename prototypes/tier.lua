-- Pure prototype builder shared by vanilla and optional modded belt tiers.
local N = require("scripts.names")
local M = {}
local G = "__sushi-packer__/graphics/"
local FACTORIOPEDIA_SIMULATION = {
  mods = { N.SIM_INTERFACE },
  init = 'remote.call("' .. N.SIM_INTERFACE .. '", "scene", "factoriopedia")',
  init_update_count = 900,
  checkboard = true,
}

local function layers(base)
  return { layers = {
    { filename = base .. ".png", width = 128, height = 128, scale = 0.5 },
    { filename = base .. "-shadow.png", width = 128, height = 128, scale = 0.5, draw_as_shadow = true },
  } }
end
local function picture(tier, dir)
  return layers(G .. "entity/sushi-packer/" .. tier .. "/sushi-packer-" .. tier .. "-" .. dir)
end
local function icon(tier) return G .. "icons/sushi-packer-" .. tier .. ".png" end

function M.make(tier, opts)
  opts = opts or {}
  local T = N.TIER[tier]
  local source_belt = data.raw["transport-belt"] and data.raw["transport-belt"][T.belt]
  if not source_belt then error("sushi-packer: missing transport-belt prototype for tier " .. tier .. ": " .. tostring(T.belt)) end
  local recipe = T
  if T.extra and (not data.raw.item["stack-inserter"] or not data.raw.item["quantum-processor"]) then recipe = N.EXTRA_RECIPE_NOSA end
  local root_recipe = opts.root and T.extra and N.EXTRA_RECIPE_ROOT
  local protos = {}
  local previous_tier = opts.prev

  protos[#protos + 1] = {
    type = "item",
    name = N.item(tier),
    icon = icon(tier), icon_size = 64,
    subgroup = N.SUBGROUP,
    order = "a[sushi-packer]-" .. string.char(96 + opts.index),
    place_result = N.placer(tier),
    stack_size = 50,
    weight = N.ITEM_WEIGHT,
    factoriopedia_simulation = FACTORIOPEDIA_SIMULATION,
  }

  protos[#protos + 1] = {
    type = "recipe",
    name = N.item(tier),
    enabled = false,
    energy_required = recipe.craft_s,
    ingredients = {
      { type = "item", name = root_recipe and root_recipe.base or previous_tier and N.item(previous_tier) or N.RECIPE_BASE, amount = 1 },
      { type = "item", name = T.splitter, amount = 1 },
      { type = "item", name = recipe.inserter, amount = (recipe.inserters or 2) * (root_recipe and root_recipe.mult or 1) },
      { type = "item", name = recipe.circuit, amount = recipe.circuits * (root_recipe and root_recipe.mult or 1) },
    },
    results = { { type = "item", name = N.item(tier), amount = 1 } },
  }

  local belt_tech = data.raw.technology[T.tech]
  if (not belt_tech or not belt_tech.unit) and opts.strict then
    error("sushi-packer: matching belt technology has no research unit: " .. T.tech)
  elseif not belt_tech or not belt_tech.unit then
    return protos
  end
  local prerequisites = { T.tech }
  local prerequisite_set = { [T.tech] = true }
  local function add_prerequisite(name)
    if not prerequisite_set[name] then
      prerequisite_set[name] = true
      prerequisites[#prerequisites + 1] = name
    end
  end
  if previous_tier then
    add_prerequisite(N.tech(previous_tier))
  elseif not opts.root then
    add_prerequisite("steel-processing")
  end

  local recipe_ingredients = protos[2].ingredients
  local technology_names = {}
  for name in pairs(data.raw.technology) do technology_names[#technology_names + 1] = name end
  table.sort(technology_names)
  for _, ingredient in ipairs(recipe_ingredients) do
    for _, technology_name in ipairs(technology_names) do
      if technology_name ~= N.tech(tier) then
        local technology = data.raw.technology[technology_name]
        for _, effect in ipairs(technology.effects or {}) do
          if effect.type == "unlock-recipe" and effect.recipe == ingredient.name then
            add_prerequisite(technology_name)
            break
          end
        end
      end
    end
  end

  local research_ingredients, research_ingredient_set = {}, {}
  for _, prerequisite in ipairs(prerequisites) do
    local technology = data.raw.technology[prerequisite]
    if technology and technology.unit then
      for _, ingredient in ipairs(technology.unit.ingredients or {}) do
        local name = ingredient[1]
        if not research_ingredient_set[name] then
          research_ingredient_set[name] = true
          research_ingredients[#research_ingredients + 1] = { name, ingredient[2] }
        end
      end
    end
  end
  protos[#protos + 1] = {
    type = "technology",
    name = N.tech(tier),
    icon = icon(tier), icon_size = 64,
    prerequisites = prerequisites,
    effects = { { type = "unlock-recipe", recipe = N.item(tier) } },
    unit = {
      count = math.ceil(belt_tech.unit.count * N.TECH_COST_FACTOR),  -- uint even for odd belt counts
      time = belt_tech.unit.time,
      ingredients = research_ingredients,
    },
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
    fast_replaceable_group = N.BELT_GROUP,
  }
  for k, v in pairs(common) do placer[k] = v end
  protos[#protos + 1] = placer

  local body = table.deepcopy(source_belt)
  body.name = N.body(tier)
  body.icon, body.icon_size = icon(tier), 64
  body.icons = nil
  body.localised_name = { "entity-name." .. N.placer(tier) }
  body.minable = { mining_time = 0.2, result = N.item(tier) }
  body.placeable_by = { item = N.item(tier), count = 1 }
  body.fast_replaceable_group = N.FAST_REPLACE_GROUP
  body.next_upgrade = opts.next and N.body(opts.next) or nil
  body.related_underground_belt = nil
  body.corpse = N.remnant(tier)
  body.max_health = 350
  body.se_allow_in_space = true
  body.factoriopedia_simulation = FACTORIOPEDIA_SIMULATION
  body.hidden_in_factoriopedia = false
  protos[#protos + 1] = body

  protos[#protos + 1] = {
    type = "simple-entity-with-owner",
    name = N.hood(tier),
    icon = icon(tier), icon_size = 64,  -- engine asks icon of every entity (load error without)
    -- off-grid + one-tile box: entity without size snaps to tile corner (game 2026-10-02: hood sat at 11,19 for packer at 10.5,18.5)
    flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "not-upgradable", "not-flammable", "not-in-kill-statistics", "not-repairable", "placeable-neutral", "placeable-off-grid" },
    collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } },
    picture = placer.picture,
    collision_mask = { layers = {} },
    selectable_in_game = false,
    hidden = true,
    hidden_in_factoriopedia = true,
    max_health = 350,
    render_layer = "object",
  }

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
      hidden = true,
      hidden_in_factoriopedia = true,
      factoriopedia_simulation = nil,
      next_upgrade = nil,
      se_allow_in_space = true,  -- v10 Q10: Space Exploration lets flagged containers stand on space tiles; engine ignores key
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


return M
