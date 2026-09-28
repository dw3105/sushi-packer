-- Offline data-stage fixture (SP-02): fake `data` + `data.raw` for prototypes/*.lua under lua5.2.
-- Values = real data.raw dump of Factorio 2.0.77 + space-age (2.1.20 identical, checked 2026-09-26, FND-0007).
-- usage: local F = require("tests.offline.fake_data"); F.reset(); dofile("prototypes/packer.lua"); F.raw.technology[...]
local F = {}

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deepcopy(v) end
  return c
end

F.TECH = {
  ["advanced-circuit"] = { prerequisites = { "plastics" }, unit = { count = 200, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 15 } },
  ["bulk-inserter"] = { prerequisites = { "fast-inserter", "logistics-2", "advanced-circuit" }, unit = { count = 150, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 30 } },
  ["electronics"] = { research_trigger = { type = "craft-item", item = "copper-plate", count = 10 } },
  ["fast-inserter"] = { prerequisites = { "automation-science-pack" }, unit = { count = 30, ingredients = { { "automation-science-pack", 1 } }, time = 15 } },
  ["logistics"] = { prerequisites = { "automation-science-pack" }, unit = { count = 20, ingredients = { { "automation-science-pack", 1 } }, time = 15 } },
  ["logistics-2"] = { prerequisites = { "logistics", "logistic-science-pack" }, unit = { count = 200, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 30 } },
  ["logistics-3"] = { prerequisites = { "production-science-pack", "lubricant" }, unit = { count = 300, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 }, { "production-science-pack", 1 } }, time = 15 } },
  ["processing-unit"] = { prerequisites = { "chemical-science-pack" }, unit = { count = 300, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 } }, time = 30 } },
  ["quantum-processor"] = { prerequisites = { "cryogenic-science-pack" }, unit = { count = 500, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 }, { "production-science-pack", 1 }, { "utility-science-pack", 1 }, { "space-science-pack", 1 }, { "metallurgic-science-pack", 1 }, { "agricultural-science-pack", 1 }, { "electromagnetic-science-pack", 1 }, { "cryogenic-science-pack", 1 } }, time = 60 } },
  ["stack-inserter"] = { prerequisites = { "carbon-fiber", "production-science-pack", "utility-science-pack", "bulk-inserter" }, unit = { count = 1000, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 }, { "production-science-pack", 1 }, { "utility-science-pack", 1 }, { "space-science-pack", 1 }, { "agricultural-science-pack", 1 } }, time = 60 } },
  ["steel-processing"] = { prerequisites = { "automation-science-pack" }, unit = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 5 } },
  ["turbo-transport-belt"] = { prerequisites = { "metallurgic-science-pack", "logistics-3" }, unit = { count = 500, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 }, { "chemical-science-pack", 1 }, { "production-science-pack", 1 }, { "space-science-pack", 1 }, { "metallurgic-science-pack", 1 } }, time = 60 } },
}

-- recipe name -> technologies whose effects unlock it (dump scan). All these recipes start disabled.
F.UNLOCK = {
  ["advanced-circuit"] = { "advanced-circuit" },
  ["bulk-inserter"] = { "bulk-inserter" },
  ["electronic-circuit"] = { "electronics" },
  ["express-splitter"] = { "logistics-3" },
  ["fast-inserter"] = { "fast-inserter" },
  ["fast-splitter"] = { "logistics-2" },
  ["inserter"] = { "electronics" },
  ["processing-unit"] = { "processing-unit" },
  ["quantum-processor"] = { "quantum-processor" },
  ["splitter"] = { "logistics" },
  ["stack-inserter"] = { "stack-inserter" },
  ["steel-chest"] = { "steel-processing" },
  ["turbo-splitter"] = { "turbo-transport-belt" },
}

-- v9 S0 fixture (FND-0023, real P1 dumps 2026-09-28): belt-family prototypes per mod set. Vanilla belts always
-- present after reset(). F.with_mods(set) adds that set's belts, splitters (recipe + item) and belt techs.
-- Belt speed = tiles/tick (x 480 = items/s). Unit counts/prereqs as dumped; packs trimmed to what cost tests need.
F.BELTS = {
  ["transport-belt"] = 0.03125, ["fast-transport-belt"] = 0.0625, ["express-transport-belt"] = 0.09375, ["turbo-transport-belt"] = 0.125,
}
local SP, LP, CP, PP, UP = "automation-science-pack", "logistic-science-pack", "chemical-science-pack", "production-science-pack", "utility-science-pack"
local function unit(count, packs) local ing = {} for _, p in ipairs(packs) do ing[#ing + 1] = { p, 1 } end return { count = count, time = 60, ingredients = ing } end
-- row: belt, speed, splitter, tech, tech unit, tech prereqs, hidden
local ROWS = {
  hyper = { "planetaris-hyper-transport-belt", 0.15625, "planetaris-hyper-splitter", "planetaris-hyper-transport-belt",
    unit(3000, { SP, LP, CP, PP, "space-science-pack", "metallurgic-science-pack", "planetaris-compression-science-pack" }), { "planetaris-compression-science", "turbo-transport-belt" } },
  superior = { "kr-superior-transport-belt", 0.1875, "kr-superior-splitter", "kr-logistic-5",
    unit(2000, { PP, UP, "space-science-pack", "kr-singularity-tech-card" }), { "kr-singularity-tech-card", "turbo-transport-belt" } },
  advanced = { "kr-advanced-transport-belt", 0.125, "kr-advanced-splitter", "kr-logistic-4", unit(500, { SP, LP, CP, UP }), { "logistics-3" }, true },
  bob = { "bob-ultimate-transport-belt", 0.15625, "bob-ultimate-splitter", "logistics-5", unit(300, { SP, LP, CP, PP, UP }), { "logistics-4" } },
  ub1 = { "ultra-fast-belt", 0.1875, "ultra-fast-splitter", "ultra-fast-logistics", unit(300, { SP, LP, CP }), { "logistics-3" } },
  ub2 = { "extreme-fast-belt", 0.28125, "extreme-fast-splitter", "extreme-fast-logistics", unit(300, { SP, LP, CP, PP }), { "ultra-fast-logistics" } },
  ub3 = { "ultra-express-belt", 0.375, "ultra-express-splitter", "ultra-express-logistics", unit(400, { SP, LP, CP, PP }), { "extreme-fast-logistics" } },
  ub4 = { "extreme-express-belt", 0.46875, "extreme-express-splitter", "extreme-express-logistics", unit(400, { SP, LP, CP, PP, UP }), { "ultra-express-logistics" } },
  ub5 = { "ultimate-belt", 0.5625, "original-ultimate-splitter", "ultimate-logistics", unit(500, { SP, LP, CP, PP, UP }), { "extreme-express-logistics" } },
  bb = { "BetterBelts_ultra-transport-belt", 0.2, "BetterBelts_ultra-splitter", "BetterBelts_ultra-class", unit(150, { SP, LP, CP, PP }), { "logistics-3" } },
}
F.MODSETS = {
  vanilla = {}, arig = { "hyper" }, hyarion = { "hyper" }, ["arig-off"] = { "hyper" }, k2so = { "superior", "advanced" },
  ["arig-k2so"] = { "hyper", "superior", "advanced" }, bob = { "bob" }, ubsa = { "ub1", "ub2", "ub3", "ub4", "ub5" }, bb = { "bb" },
  all = { "hyper", "superior", "advanced", "bob", "ub1", "ub2", "ub3", "ub4", "ub5", "bb" },
}

local function add_belt(raw, name, speed, hidden)
  raw["transport-belt"][name] = { type = "transport-belt", name = name, speed = speed, hidden = hidden or nil }
end

function F.with_mods(set)
  local raw = F.raw
  for _, key in ipairs(assert(F.MODSETS[set], "unknown mod set " .. tostring(set))) do
    local r = ROWS[key]
    local belt, speed, splitter, tech, u, prereq, hidden = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
    add_belt(raw, belt, speed, hidden)
    raw.technology[tech] = { type = "technology", name = tech, prerequisites = deepcopy(prereq), unit = deepcopy(u), hidden = hidden or nil,
      effects = { { type = "unlock-recipe", recipe = belt }, { type = "unlock-recipe", recipe = splitter } } }
    for _, n in ipairs({ belt, splitter }) do
      raw.recipe[n] = { type = "recipe", name = n, enabled = false, hidden = hidden or nil }
      raw.item[n] = { type = "item", name = n, hidden = hidden or nil }
    end
  end
  if set == "hyarion" then
    raw.technology["planetaris-hyper-transport-belt"].prerequisites = { "planetaris-polishing-science-pack", "turbo-transport-belt" }
  end
  if set == "arig-off" then
    raw["transport-belt"]["planetaris-hyper-transport-belt"].hidden = true
    raw.technology["planetaris-hyper-transport-belt"].hidden = true
  end
  return F
end

function F.reset()
  local raw = { technology = {}, recipe = {}, item = {}, container = {}, ["simple-entity-with-owner"] = {}, corpse = {},
    ["tips-and-tricks-item"] = {}, ["tips-and-tricks-item-category"] = {}, ["transport-belt"] = {} }
  for name, speed in pairs(F.BELTS) do add_belt(raw, name, speed) end
  for name, t in pairs(F.TECH) do
    local tech = deepcopy(t); tech.type = "technology"; tech.name = name; tech.effects = {}
    raw.technology[name] = tech
  end
  local names = {}
  for recipe in pairs(F.UNLOCK) do names[#names + 1] = recipe end
  table.sort(names)
  for _, recipe in ipairs(names) do
    raw.recipe[recipe] = { type = "recipe", name = recipe, enabled = false }
    raw.item[recipe] = { type = "item", name = recipe }
    for _, tn in ipairs(F.UNLOCK[recipe]) do
      local e = raw.technology[tn].effects
      e[#e + 1] = { type = "unlock-recipe", recipe = recipe }
    end
  end
  F.raw = raw
  F.extended = {}
  _G.data = { raw = raw, extend = function(self, list)
    for _, p in ipairs(list) do
      raw[p.type] = raw[p.type] or {}
      raw[p.type][p.name] = p
      F.extended[#F.extended + 1] = p
    end
  end }
  table.deepcopy = deepcopy
  _G.circuit_connector_definitions = { chest = { fake = "chest-connector" } }
  _G.default_circuit_wire_max_distance = 9
  return F
end

return F
