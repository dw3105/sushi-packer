-- Data stage: the vanilla family is built with the shared tier prototype generator.
local N = require("scripts.names")
local tier = require("prototypes.tier")

data:extend({ { type = "item-subgroup", name = N.SUBGROUP, group = "logistics", order = "b-a" } })
local built = {}
for index, key in ipairs(N.TIERS) do
  local T = N.TIER[key]
  local belt = data.raw["transport-belt"] and data.raw["transport-belt"][T.belt]
  local tech = data.raw.technology and data.raw.technology[T.tech]
  if not N.OPTIONAL_VANILLA[key] or (belt and tech and tech.unit) then built[#built + 1] = { key = key, index = index } end
end
for position, entry in ipairs(built) do
  local key = entry.key
  data:extend(tier.make(key, {
    prev = built[position - 1] and built[position - 1].key,
    next = built[position + 1] and built[position + 1].key,
    index = entry.index,
    strict = true,
  }))
end
