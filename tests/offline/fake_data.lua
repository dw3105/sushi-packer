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

function F.reset()
  local raw = { technology = {}, recipe = {}, item = {}, container = {}, ["simple-entity-with-owner"] = {}, corpse = {},
    ["tips-and-tricks-item"] = {}, ["tips-and-tricks-item-category"] = {} }
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
