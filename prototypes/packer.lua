-- Data stage: the vanilla family is built with the shared tier prototype generator.
local N = require("scripts.names")
local tier = require("prototypes.tier")

data:extend({ { type = "item-subgroup", name = N.SUBGROUP, group = "logistics", order = "b-a" } })
for index, key in ipairs(N.TIERS) do
  data:extend(tier.make(key, {
    prev = N.TIERS[index - 1],
    next = N.TIERS[index + 1],
    index = index,
    strict = true,
  }))
end
