-- Every prototype, sprite, setting and input name. Frozen (SP-01): data and control stage both read this file.
local N = {}

N.MOD = "sushi-packer"
N.TIERS = { "yellow", "red", "blue", "turbo" }
N.DIRS = { "north", "east", "south", "west" }
N.LED_STATES = { "green", "yellow", "red" }
N.SLOTS = 48
N.MAX_BELT_STACK = 4

-- Per tier: matching vanilla belt, its tech, belt-items per lane per tick (O-4, E-4).
-- Recipe (U-2, author 2026-09-26): base (steel-chest or previous tier box) + 1 splitter + 2 inserter + circuits.
N.TIER = {
  yellow = { belt = "transport-belt",         tech = "logistics",            lane_rate = 0.125,
             splitter = "splitter",         inserter = "inserter",      circuit = "electronic-circuit", circuits = 5, craft_s = 30 },
  red    = { belt = "fast-transport-belt",    tech = "logistics-2",          lane_rate = 0.25,
             splitter = "fast-splitter",    inserter = "fast-inserter",  circuit = "advanced-circuit",  circuits = 5, craft_s = 45 },
  blue   = { belt = "express-transport-belt", tech = "logistics-3",          lane_rate = 0.375,
             splitter = "express-splitter", inserter = "bulk-inserter",  circuit = "processing-unit",   circuits = 5, craft_s = 60 },
  turbo  = { belt = "turbo-transport-belt",   tech = "turbo-transport-belt", lane_rate = 0.5,
             splitter = "turbo-splitter",   inserter = "stack-inserter", circuit = "quantum-processor", circuits = 2, craft_s = 120 },
}
N.RECIPE_BASE = "steel-chest"       -- yellow base; later tiers use previous tier item
N.TECH_COST_FACTOR = 1.5            -- U-1: count = belt tech count x 1.5 (Deadlock pattern)
N.ITEM_WEIGHT = 20000               -- U-4: 20 kg, 50 per rocket
N.TIPS = "sushi-packer-tips"        -- U-5: tips-and-tricks-item
N.SUBGROUP = "sushi-packer"         -- U-7: own item-subgroup row after belts (group logistics)
N.SIM_INTERFACE = "sushi-packer"    -- U-8: remote interface simulations call (scene)
N.BELT_GROUP = "transport-belt"     -- E-9: placer fast_replaceable_group (FND-0009)

-- U-7 (v6, author 2026-09-26): vanilla belt-series names. yellow "sushi-packer", red "fast-sushi-packer",
-- blue "express-sushi-packer", turbo "turbo-sushi-packer". Tier keys (yellow..turbo) stay internal (storage, graphics).
N.PREFIX = { yellow = "", red = "fast-", blue = "express-", turbo = "turbo-" }
function N.item(tier) return N.PREFIX[tier] .. "sushi-packer" end
function N.placer(tier) return N.item(tier) .. "-placer" end
function N.variant(tier, dir) return N.item(tier) .. "-" .. dir end
function N.remnant(tier) return N.item(tier) .. "-remnants" end
function N.tech(tier) return N.item(tier) end
-- v1.1 names, only for migrations/*.json and their test.
function N.old_item(tier) return "sushi-packer-" .. tier end
function N.led(state, dir) return "sushi-packer-led-" .. state .. "-" .. dir end

N.SETTING_TIMEOUT = "sushi-packer-flush-timeout"
N.INPUT_ROTATE = "sushi-packer-rotate"
N.INPUT_REVERSE_ROTATE = "sushi-packer-reverse-rotate"
N.FAST_REPLACE_GROUP = "sushi-packer"

-- Reverse lookups: entity name -> {tier, dir}; placer name -> tier.
N.VARIANTS = {}
N.PLACERS = {}
for _, tier in ipairs(N.TIERS) do
  N.PLACERS[N.placer(tier)] = tier
  for _, dir in ipairs(N.DIRS) do
    N.VARIANTS[N.variant(tier, dir)] = { tier = tier, dir = dir }
  end
end

return N
